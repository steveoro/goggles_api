# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:team, city: FactoryBot.create(:city)) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Team') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::Team).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/team/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_team_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_team_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get api_v3_team_path(id: -1), headers: fixture_headers }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/team/:id' do
    let(:new_team_values) { FactoryBot.build(:team) }
    let(:expected_changes) do
      [
        { name: new_team_values.name, editable_name: new_team_values.editable_name },
        { city_id: new_team_values.city_id, address: new_team_values.address, zip: new_team_values.zip },
        { phone_mobile: new_team_values.phone_mobile, phone_number: new_team_values.phone_number },
        { e_mail: new_team_values.e_mail, contact_name: new_team_values.contact_name },
        { notes: new_team_values.notes },
        { home_page_url: new_team_values.home_page_url }
      ].sample
    end
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_team_values).to be_a(GogglesDb::Team)
      expect(expected_changes).to be_an(Hash)
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before(:each) { put(api_v3_team_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having the proper grants,' do
        before(:each) { put(api_v3_team_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_team_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { put(api_v3_team_path(id: -1), params: expected_changes, headers: crud_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/team' do
    let(:built_row) { FactoryBot.build(:team) }
    let(:admin_user)  { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
    before(:each) do
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::Team).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_team_path, params: built_row.attributes, headers: admin_headers) }
        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before(:each) { post(api_v3_team_path, params: built_row.attributes, headers: crud_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_team_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_team_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using invalid parameters,' do
      before(:each) { post(api_v3_team_path, params: built_row.attributes.merge(name: nil), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.creation_failure'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/teams/' do
    context 'when using a valid authentication' do
      let(:fixture_city_id) { [2, 3, 4, 5, 37].sample }
      let(:default_per_page)  { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) { expect(GogglesDb::Team.where(city_id: fixture_city_id).count).to be_positive }

      context 'without any filters,' do
        before(:each) { get(api_v3_teams_path, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific city_id,' do
        before(:each) { get(api_v3_teams_path, params: { city_id: fixture_city_id }, headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::Team.where(city_id: fixture_city_id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        # (We can't really assert pagination links here, it's enough to test these in the context below)
      end

      context 'when filtering by name,' do
        let(:search_term) { GogglesDb::Team.select(:name).limit(50).sample.name.split.first }
        let(:data_domain) { GogglesDb::Team.for_name(search_term) }
        let(:expected_team) { data_domain.first }
        let(:expected_row_count) { data_domain.count }
        before(:each) { get(api_v3_teams_path, params: { name: search_term }, headers: fixture_headers) }

        it 'includes the expected row in the result array' do
          result_ids = JSON.parse(response.body).map { |row| row['id'] }
          expect(result_ids).to include(expected_team.id)
        end
        # Typically any results filtered by name will be just a single row fitting
        # in a single page (w/o pagination links), but with random names we can't be sure:
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_teams_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_teams_path, params: { city_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
