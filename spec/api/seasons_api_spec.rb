# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SeasonsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_season) { FactoryBot.create(:season) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_season).to be_a(GogglesDb::Season).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/season/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_season_path(id: fixture_season.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected row as JSON' do
        expect(response.body).to eq(fixture_season.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_season_path(id: fixture_season.id), headers: { 'Authorization' => 'you wish!' }
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_season_path(id: -1), headers: fixture_headers
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/season/:id' do
    context 'when using valid parameters,' do
      let(:expected_changes) do
        [
          { description: 'FIXTURE Season test 1' },
          { description: 'FIXTURE Season test 2', season_type_id: GogglesDb::SeasonType.send(%w[mas_fin mas_csi mas_uisp].sample).id },
          { description: 'FIXTURE Season test 3', has_individual_rank: true },
          { description: 'FIXTURE Season test 4', badge_fee: 24.99 },
          { description: 'FIXTURE Season test 5', begin_date: Date.today - 3.months, end_date: Date.today + 5.months },
          { description: 'FIXTURE Season test 6', header_year: "#{(Date.today - 3.months).year}/#{(Date.today + 5.months).year}" }
        ].sample
      end
      before(:each) do
        put(
          api_v3_season_path(id: fixture_season.id),
          params: expected_changes,
          headers: fixture_headers
        )
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'updates the row and returns true' do
        expect(response.body).to eq('true')
        updated_row = fixture_season.reload
        expected_changes.each do |key, _value|
          expect(updated_row.send(key)).to eq(expected_changes[key])
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_season_path(id: fixture_season.id),
          params: { description: 'FIXTURE Season' },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_season_path(id: -1),
          params: { description: 'FIXTURE Season' },
          headers: fixture_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/seasons/' do
    context 'when using a valid authentication' do
      let(:fixture_season_type_id) { GogglesDb::SeasonType.send(%w[mas_fin mas_csi mas_uisp].sample).id } # Season types with >= default_per_page results
      let(:existing_season)        { GogglesDb::Season.find([171, 172, 181, 182, 191, 192].sample) }
      let(:header_year)            { existing_season.header_year }
      let(:begin_date)             { existing_season.begin_date }
      let(:end_date)               { existing_season.end_date }
      let(:default_per_page)       { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) { expect(existing_season).to be_a(GogglesDb::Season).and be_valid }

      context 'without any filters,' do
        before(:each) do
          get(api_v3_seasons_path, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific season_type_id,' do
        before(:each) do
          get(api_v3_seasons_path, params: { season_type_id: fixture_season_type_id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
        # (We can't really assert pagination links here)
      end

      context 'filtering by a specific header_year,' do
        before(:each) do
          get(api_v3_seasons_path, params: { header_year: header_year }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
        # (We can't really assert pagination links here)
      end

      context 'filtering by a specific header_year,' do
        before(:each) do
          get(api_v3_seasons_path, params: { begin_date: begin_date, end_date: end_date }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
        # (We can't really assert pagination links here)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get(api_v3_seasons_path, headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) do
        get(api_v3_seasons_path, params: { header_year: '1969/1970' }, headers: fixture_headers)
      end
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
