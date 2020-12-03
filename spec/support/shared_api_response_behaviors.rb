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
#-- ---------------------------------------------------------------------------
#++

shared_examples_for 'an empty but successful JSON response' do
  it 'is successful anyway' do
    expect(response).to be_successful
  end
  it 'returns a nil JSON body' do
    expect(JSON.parse(response.body)).to be nil
  end
end

shared_examples_for 'an empty but successful JSON list response' do
  it 'is successful anyway' do
    expect(response).to be_successful
  end
  it 'returns an empty JSON list body' do
    expect(JSON.parse(response.body)).to eq([])
  end
end
#-- ---------------------------------------------------------------------------
#++

# REQUIRES/ASSUMES:
# - many results, multiple pages (always pagination)
# - 'default_per_page' to be already set (default pagination size)
shared_examples_for 'response with pagination links & values in headers' do
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
shared_examples_for 'single response without pagination links in headers' do
  it 'does not contain the pagination values or links in the response headers' do
    expect(response.headers['Page']).to eq('1')
    expect(response.headers['Per-Page']).to eq(default_per_page.to_s)
    expect(response.headers['Total']).to eq('1')
    expect(response.headers['Link']).to be nil
  end
end

# REQUIRES/ASSUMES:
# - more than 1 result, possibly just 1 page (no pagination) OR multiple pages
# - 'default_per_page' to be already set (default pagination size)
# - 'expected_row_count' to be already set (row count for expected result)
shared_examples_for 'multiple row response either with OR without pagination links' do
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
