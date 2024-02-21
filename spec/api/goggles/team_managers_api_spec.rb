# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamManagersAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:managed_affiliation) }
  # Admin:
  let(:admin_user) { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)    { FactoryBot.create(:user) }
  let(:crud_grant)   { FactoryBot.create(:admin_grant, user: crud_user, entity: 'ManagedAffiliation') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::ManagedAffiliation).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/team_manager/:id' do
    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_team_manager_path(id: fixture_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_team_manager_path(id: fixture_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_team_manager_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_team_manager_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_team_manager_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_team_manager_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_team_manager_path(id: -1), headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/team_manager/:id' do
    let(:expected_changes) do
      [
        { user_id: GogglesDb::User.all.sample.id }, # Admins must be able to set any user as Team Manager
        { team_affiliation_id: GogglesDb::TeamAffiliation.first(50).sample.id }
      ].sample
    end

    before do
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_team_manager_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_team_manager_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/team_manager' do
    let(:new_manager) { FactoryBot.create(:user) }
    let(:new_affiliation) { FactoryBot.create(:team_affiliation) }
    let(:built_row) { FactoryBot.build(:managed_affiliation, manager: new_manager, team_affiliation: new_affiliation) }

    before do
      expect(new_manager).to be_a(GogglesDb::User).and be_valid
      expect(new_affiliation).to be_a(GogglesDb::TeamAffiliation).and be_valid
      expect(built_row).to be_a(GogglesDb::ManagedAffiliation).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_team_manager_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        let(:crud_user) { FactoryBot.create(:user) }
        let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'TeamAffiliation') }
        let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

        before do
          expect(crud_user).to be_a(GogglesDb::User).and be_valid
          expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
          expect(crud_headers).to be_an(Hash).and have_key('Authorization')
          post(api_v3_team_manager_path, params: built_row.attributes, headers: crud_headers)
        end

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_team_manager_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_team_manager_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before { post(api_v3_team_manager_path, params: { user_id: built_row.user_id, team_affiliation_id: -1 }, headers: admin_headers) }

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

  describe 'DELETE /api/v3/team_manager/:id' do
    let(:deletable_row) { FactoryBot.create(:managed_affiliation) }

    before { expect(deletable_row).to be_a(GogglesDb::ManagedAffiliation).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_team_manager_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_team_manager_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_team_manager_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_team_manager_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_team_manager_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_team_manager_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_team_manager_path(id: -1), headers: admin_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/team_managers/' do
    let(:default_per_page) { 25 }

    context 'without any filters,' do
      let(:expected_row_count) { GogglesDb::ManagedAffiliation.count }
      before do
        expect(GogglesDb::ManagedAffiliation.count).to be_positive
        expect(expected_row_count).to be_positive
      end

      context 'with an account having ADMIN grants,' do
        before { get(api_v3_team_managers_path, headers: admin_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_team_managers_path, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_team_managers_path, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_team_managers_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_team_managers_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific team_affiliation_id,' do
      let(:fixture_ta_id) { GogglesDb::ManagedAffiliation.first(150).sample.team_affiliation_id }
      let(:expected_row_count) { GogglesDb::ManagedAffiliation.where(team_affiliation_id: fixture_ta_id).count }
      before do
        FactoryBot.create_list(:managed_affiliation, 10, team_affiliation_id: fixture_ta_id)
        expect(GogglesDb::ManagedAffiliation.count).to be_positive
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { team_affiliation_id: fixture_ta_id }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific user_id,' do
      let(:fixture_user_id) { GogglesDb::ManagedAffiliation.first(150).sample.user_id }
      let(:expected_row_count) { GogglesDb::ManagedAffiliation.where(user_id: fixture_user_id).count }
      before do
        FactoryBot.create_list(:managed_affiliation, 26, user_id: fixture_user_id) # rubocop:disable FactoryBot/ExcessiveCreateList
        expect(GogglesDb::ManagedAffiliation.count).to be_positive
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { user_id: fixture_user_id }, headers: admin_headers)
      end

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when filtering by a specific team_id,' do
      let(:fixture_team_id) { 1 } # (we don't need to create fixture Team managers for this one)
      let(:expected_row_count) do
        GogglesDb::ManagedAffiliation.joins(:season, :team, :manager)
                                     .includes(:season, :team, :manager)
                                     .where('teams.id': fixture_team_id).count
      end
      before do
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { team_id: fixture_team_id }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific season_id,' do
      let(:fixture_season_id) { [152, 162].sample } # (we don't need to create fixture Team managers for this one)
      let(:expected_row_count) do
        GogglesDb::ManagedAffiliation.joins(:season, :team, :manager)
                                     .includes(:season, :team, :manager)
                                     .where('seasons.id': fixture_season_id).count
      end
      before do
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { season_id: fixture_season_id }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by the manager name,' do
      let(:fixture_row_name) { '%leega%' }
      let(:data_domain) do
        GogglesDb::ManagedAffiliation.joins(:manager)
                                     .includes(:manager)
                                     .where('users.name LIKE ?', fixture_row_name)
      end
      let(:expected_row_count) { data_domain.count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { manager_name: fixture_row_name }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by the team name,' do
      # This is needed due to anonymized data:
      let(:fixture_row_name) { "%#{GogglesDb::Team.first.name.split.first}%" }
      let(:data_domain) do
        team_affiliation_ids = GogglesDb::TeamAffiliation.where(team_id: GogglesDb::Team.first.id).first(15).map(&:id)
        team_affiliation_ids.each { |ta_id| FactoryBot.create(:managed_affiliation, team_affiliation_id: ta_id) }
        domain = GogglesDb::ManagedAffiliation.joins(:team)
                                              .includes(:team)
                                              .where('teams.name LIKE ?', fixture_row_name)
        expect(domain.count).to be_positive
        domain
      end
      let(:expected_row_count) { data_domain.count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { team_name: fixture_row_name }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by the season description,' do
      let(:fixture_row_name) { %w[%fin% %csi%].sample }
      let(:data_domain) do
        domain = GogglesDb::ManagedAffiliation.joins(:season)
                                              .includes(:season)
                                              .where('seasons.description LIKE ?', fixture_row_name)
        expect(domain.count).to be_positive
        domain
      end
      let(:expected_row_count) { data_domain.count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_team_managers_path, params: { season_description: fixture_row_name }, headers: admin_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_team_managers_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_team_managers_path, params: { user_id: 0 }, headers: admin_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
