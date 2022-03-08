# frozen_string_literal: true

shared_examples_for 'a failed auth attempt due to invalid JWT' do
  it 'is NOT successful' do
    expect(response).not_to be_successful
  end

  it 'responds with a generic error message and its details in the header' do
    result = JSON.parse(response.body)
    expect(result).to have_key('error')
    expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
    expect(response.headers).to have_key('X-Error-Detail')
    expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.jwt.invalid'))
  end
end

shared_examples_for 'a failed auth attempt due to unauthorized credentials' do
  it 'is NOT successful' do
    expect(response).not_to be_successful
  end

  it 'responds with a generic error message and its details in the header' do
    result = JSON.parse(response.body)
    expect(result).to have_key('error')
    expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
    expect(response.headers).to have_key('X-Error-Detail')
    expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.invalid_user_grants'))
  end
end
#-- ---------------------------------------------------------------------------
#++

shared_examples_for 'a request refused during Maintenance (except for admins)' do
  it 'is NOT successful' do
    expect(response).not_to be_successful
  end

  it 'responds with the maintenance error message' do
    result = JSON.parse(response.body)
    expect(result).to have_key('error')
    expect(result['error']).to eq(I18n.t('api.message.status.maintenance'))
  end
end
#-- ---------------------------------------------------------------------------
#++

shared_examples_for 'a successful request that has positive usage stats' do
  it 'is successful' do
    expect(response).to be_successful
  end

  it 'has a positive usage statistics' do
    route_key = "#{response.request.env['REQUEST_METHOD']} #{response.request.path.gsub(%r{/-?\d+}, '/:id')}"
    usage_row = GogglesDb::APIDailyUse.find_by(route: route_key, day: Time.zone.today)
    expect(usage_row).to be_a(GogglesDb::APIDailyUse).and be_valid
    expect(usage_row.count).to be_positive
  end
end

shared_examples_for 'an empty but successful JSON response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns a nil JSON body' do
    expect(JSON.parse(response.body)).to be nil
  end
end

shared_examples_for 'a successful response with an empty body' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns a nil body' do
    expect(response.body).to be_empty
  end
end

shared_examples_for 'an empty but successful JSON list response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns an empty JSON list body' do
    expect(JSON.parse(response.body)).to eq([])
  end
end

# REQUIRES/ASSUMES:
# - 'fixture_row' is the fetched row (request is returning fixture_row.to_json)
shared_examples_for 'a successful JSON row response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns the selected row as JSON' do
    expect(response.body).to eq(fixture_row.to_json)
  end
end

# REQUIRES/ASSUMES:
# - 'fixture_row' is the updated row
# - 'expected_changes' is the attribute hash containing the updates
shared_examples_for 'a successful JSON PUT response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns true' do
    expect(response.body).to eq('true')
  end

  it 'updates the row' do
    updated_row = fixture_row.reload
    expected_changes.each do |key, value|
      # Adapt expected changes hash to the JSON-ified result which will store floats as strings so that the comparison is simpler:
      # value = value.to_s if value.is_a?(BigDecimal) || value.is_a?(Float)
      expect(updated_row.send(key).to_s).to eq(value.to_s)
    end
  end
end

# REQUIRES/ASSUMES:
# - 'deletable_row' is the destroyed row
shared_examples_for 'a successful JSON DELETE response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns true' do
    expect(response.body).to eq('true')
  end

  it 'deletes the specified row' do
    expect { deletable_row.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end

# REQUIRES/ASSUMES:
# - 'built_row' should include all parameters as attributes (will reject some attributes such as IDs or timestamps)
shared_examples_for 'a successful JSON POST response' do
  it_behaves_like('a successful request that has positive usage stats')
  it 'returns an OK message and the new row as a JSON object' do
    result = JSON.parse(response.body)
    expect(result).to have_key('msg').and have_key('new')
    expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
    attr_extractor = ->(hash) { hash.reject { |key, _value| %w[id lock_version created_at updated_at].include?(key.to_s) } }
    resulting_hash = attr_extractor.call(result['new'])
    expected_hash  = attr_extractor.call(built_row.attributes)
    # Adapt expected hash to the JSON-ified result which will store floats as strings so that the comparison is simpler:
    expected_hash.each do |key, val|
      expected_hash[key] = val.to_json.delete('"') if val.is_a?(BigDecimal) || val.is_a?(Float) || val.is_a?(Date) || val.is_a?(Time)
    end
    expect(resulting_hash).to eq(expected_hash)
  end
end
#-- ---------------------------------------------------------------------------
#++

# REQUIRES/ASSUMES:
# - many results, multiple pages (always pagination)
# - 'default_per_page' to be already set (default pagination size)
shared_examples_for 'successful response with pagination links & values in headers' do
  it_behaves_like('a successful request that has positive usage stats')

  it 'returns a paginated array of JSON rows' do
    result_array = JSON.parse(response.body)
    expect(result_array).to be_an(Array)
    expect(result_array.count).to eq(default_per_page)
  end

  it 'contains the pagination values for the first data page in the response headers' do
    expect(response.headers['Page']).to eq('1')
    expect(response.headers['Per-Page']).to eq(default_per_page.to_s)
    expect(response.headers['Total'].to_i).to be_positive
  end

  it 'contains the next & last pagination links in the response headers' do
    expect(response.headers['Link']).to be_present
    expect(response.headers['Link']).to include('next').and include('last')
    # Extract the links into an Hash, keyed by the link rel name:
    page_links = {}
    response.headers['Link'].split(', ').each do |e|
      # Typical link format: "<http://www.example.com/api/v3/<ENTITY_PLURAL>?page=<NEXT_PAGE_NUM>&<FILTER_1_ID>=182&<FILTER_2_ID>=1>; rel=\"next\""
      link_with_rel = e.split('; ')
      page_links[link_with_rel.last.split(/rel="(.+)"/).last] = link_with_rel.first.delete('<>')
    end
    expect(page_links['next']).to include('page=2')
    expect(page_links['last']).to include('page=') # Don't care about the exact number of total pages
  end
end

# REQUIRES/ASSUMES:
# - just 1 result, just 1 page (no pagination)
# - 'default_per_page' to be already set (default pagination size)
shared_examples_for 'successful single response without pagination links in headers' do
  it_behaves_like('a successful request that has positive usage stats')

  it 'returns a paginated array of JSON rows' do
    result_array = JSON.parse(response.body)
    expect(result_array).to be_an(Array)
    expect(result_array.count).to eq(1)
  end

  it 'does not contain the pagination values or links in the response headers' do
    expect(response.headers['Page']).to eq('1')
    expect(response.headers['Per-Page']).to eq(default_per_page.to_s)
    expect(response.headers['Total']).to eq('1')
    expect(response.headers['Link']).to be nil
  end
end

# REQUIRES/ASSUMES:
# - multiple results, less than max-per-page (usually 25 => no pagination)
# - 'default_per_page' to be already set (default pagination size)
shared_examples_for 'successful multiple, single-page response without pagination links in headers' do
  it_behaves_like('a successful request that has positive usage stats')

  it 'returns a paginated array of JSON rows' do
    result_array = JSON.parse(response.body)
    expect(result_array).to be_an(Array)
    expect(result_array.count).to be_positive
  end

  it 'does not contain the pagination values or links in the response headers' do
    expect(response.headers['Page']).to eq('1')
    expect(response.headers['Per-Page']).to eq(default_per_page.to_s)
    expect(response.headers['Total']).to be_present
    expect(response.headers['Link']).to be nil
  end
end

# REQUIRES/ASSUMES:
# - 1 or more results, possibly just 1 page (no pagination) OR even multiple pages
# - 'default_per_page' to be already set (default pagination size)
# - 'expected_row_count' to be already set (row count for expected result)
shared_examples_for 'successful multiple row response either with OR without pagination links' do
  it_behaves_like('a successful request that has positive usage stats')

  it 'returns a paginated JSON array of associated, filtered rows' do
    result_array = JSON.parse(response.body)
    expect(result_array).to be_an(Array)
    expect(result_array.count).to eq(expected_row_count <= default_per_page ? expected_row_count : default_per_page)
  end

  it 'may or may not contain pagination links in the headers, depending on the number of results' do
    expect(response.headers['Page']).to eq('1')
    expect(response.headers['Per-Page']).to eq(default_per_page.to_s)
    expect(response.headers['Total']).to eq(expected_row_count.to_s)

    if expected_row_count <= default_per_page
      expect(response.headers['Link']).to be nil
    else
      expect(response.headers['Link']).to be_present
      expect(response.headers['Link']).to include('next').and include('last')
      # Extract the links into an Hash, keyed by the link rel name:
      page_links = {}
      response.headers['Link'].split(', ').each do |e|
        # Typical link format: "<http://www.example.com/api/v3/<ENTITY_PLURAL>?page=<NEXT_PAGE_NUM>&<FILTER_1_ID>=182&<FILTER_2_ID>=1>; rel=\"next\""
        link_with_rel = e.split('; ')
        page_links[link_with_rel.last.split(/rel="(.+)"/).last] = link_with_rel.first.delete('<>')
      end
      expect(page_links['next']).to include('page=2')
      expect(page_links['last']).to include('page=') # Don't care about the exact number of total pages
    end
  end
end
#-- ---------------------------------------------------------------------------
#++

# REQUIRES/ASSUMES:
# - 1+ results, grouped under a single 'results' array, just 1 page (no pagination), max 100 items
# - 'expected_row_count' to be already set (row count for expected result)
shared_examples_for 'successful response in Select2 bespoke format' do
  it_behaves_like('a successful request that has positive usage stats')

  it 'returns a list of rows in Select2 bespoke format' do
    result = JSON.parse(response.body)
    expect(result).to have_key('results')
    row_list = result['results']
    expect(row_list).to be_an(Array)
    expect(row_list.count).to eq(expected_row_count)
    expect(row_list).to all have_key('id').and have_key('text')
  end
end
