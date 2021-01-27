# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SeasonsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:season) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::Season).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/season/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_season_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_season_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_season_path(id: -1), headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/season/:id' do
    let(:crud_user) { FactoryBot.create(:user) }
    let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Season') }
    let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:expected_changes) do
        [
          { description: 'FIXTURE Season test 1' },
          { description: 'FIXTURE Season test 2', season_type_id: GogglesDb::SeasonType.send(%w[mas_fin mas_csi mas_uisp].sample).id },
          { description: 'FIXTURE Season test 3', individual_rank: true },
          { description: 'FIXTURE Season test 4', badge_fee: 24.99 },
          { description: 'FIXTURE Season test 5', begin_date: Date.today - 3.months, end_date: Date.today + 5.months },
          { description: 'FIXTURE Season test 6', header_year: "#{(Date.today - 3.months).year}/#{(Date.today + 5.months).year}" }
        ].sample
      end
      before(:each) { expect(expected_changes).to be_an(Hash) }

      context 'with an account having CRUD grants,' do
        before(:each) { put(api_v3_season_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having the proper grants,' do
        before(:each) { put(api_v3_season_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_season_path(id: fixture_row.id), params: { description: 'FIXTURE Season' }, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { put(api_v3_season_path(id: -1), params: { description: 'FIXTURE Season' }, headers: crud_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/seasons/' do
    context 'when using a valid authentication' do
      let(:fixture_row_type_id) { GogglesDb::SeasonType.send(%w[mas_fin mas_csi mas_uisp].sample).id } # Season types with >= default_per_page results
      let(:existing_season)        { GogglesDb::Season.find([171, 172, 181, 182, 191, 192].sample) }
      let(:header_year)            { existing_season.header_year }
      let(:begin_date)             { existing_season.begin_date }
      let(:end_date)               { existing_season.end_date }
      let(:default_per_page)       { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) { expect(existing_season).to be_a(GogglesDb::Season).and be_valid }

      context 'without any filters,' do
        before(:each) { get(api_v3_seasons_path, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific season_type_id,' do
        before(:each) { get(api_v3_seasons_path, params: { season_type_id: fixture_row_type_id }, headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
        # (We can't really assert pagination links here)
      end

      context 'when filtering by a specific header_year,' do
        before(:each) { get(api_v3_seasons_path, params: { header_year: header_year }, headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
      end

      context 'when filtering by a specific header_year,' do
        before(:each) { get(api_v3_seasons_path, params: { begin_date: begin_date, end_date: end_date }, headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to be <= default_per_page
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_seasons_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_seasons_path, params: { header_year: '1969/1970' }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
