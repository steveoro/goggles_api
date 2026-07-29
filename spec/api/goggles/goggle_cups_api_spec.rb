# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::GoggleCupsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:goggle_cup) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user:
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'GoggleCup') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::GoggleCup).and be_valid
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

  describe 'GET /api/v3/goggle_cup/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_goggle_cup_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_goggle_cup_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_goggle_cup_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::GoggleCup.exists?(0)).to be false
        get(api_v3_goggle_cup_path(id: 0), headers: fixture_headers)
      end

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/goggle_cup/:id' do
    let(:expected_changes) do
      [
        { description: 'TEST_CUP' },
        { description: 'TEST_CUP', max_points: 1500 },
        { description: 'TEST_CUP', team_constrained: false },
        { description: 'TEST_CUP', end_date: Time.zone.today }
      ].sample
    end

    before { expect(expected_changes).to be_an(Hash).and be_present }

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_goggle_cup_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_goggle_cup_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_goggle_cup_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_goggle_cup_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::GoggleCup.exists?(0)).to be false
        put(api_v3_goggle_cup_path(id: 0), params: expected_changes, headers: crud_headers)
      end

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/goggle_cup' do
    let(:persisted_team) { FactoryBot.create(:team) }
    let(:built_row) do
      FactoryBot.build(
        :goggle_cup,
        team: persisted_team,
        description: "Test Cup #{FFaker.numerify('###')}",
        season_year: 2026
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::GoggleCup).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_goggle_cup_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_goggle_cup_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_goggle_cup_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_goggle_cup_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using invalid parameters,' do
      before do
        expect(GogglesDb::Team.exists?(0)).to be false
        post(
          api_v3_goggle_cup_path,
          params: built_row.attributes.merge(team_id: 0),
          headers: admin_headers
        )
      end

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

  describe 'DELETE /api/v3/goggle_cup/:id' do
    let(:deletable_row) { FactoryBot.create(:goggle_cup) }

    before { expect(deletable_row).to be_a(GogglesDb::GoggleCup).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_goggle_cup_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_goggle_cup_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_goggle_cup_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_goggle_cup_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_goggle_cup_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_goggle_cup_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::GoggleCup.exists?(0)).to be false
        delete(api_v3_goggle_cup_path(id: 0), headers: admin_headers)
      end

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/goggle_cups/' do
    let(:default_per_page) { 50 }

    context 'when using a valid authentication' do
      context 'without any filters,' do
        before do
          existing = GogglesDb::GoggleCup.count
          FactoryBot.create_list(:goggle_cup, default_per_page - existing + 5) if existing < default_per_page
          get(api_v3_goggle_cups_path, headers: fixture_headers)
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_goggle_cups_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific team_id,' do
        let(:expected_row_count) { GogglesDb::GoggleCup.where(team_id: fixture_row.team_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_goggle_cups_path, params: { team_id: fixture_row.team_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific season_year,' do
        let(:expected_row_count) { GogglesDb::GoggleCup.where(season_year: fixture_row.season_year).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_goggle_cups_path, params: { season_year: fixture_row.season_year }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_goggle_cups_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before do
        expect(GogglesDb::Team.exists?(0)).to be false
        get(api_v3_goggle_cups_path, params: { team_id: 0 }, headers: fixture_headers)
      end

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/goggle_cups/search' do
    let(:search_description) { fixture_row.description.to_s }

    context 'when using a valid authentication' do
      let(:default_per_page) { 50 }

      context 'without any filters (missing description parameter),' do
        before { get(api_v3_goggle_cups_search_path, headers: fixture_headers) }

        it 'is NOT successful' do
          expect(response).not_to be_successful
        end

        it 'responds with a grape error message about the missing required parameter' do
          result = JSON.parse(response.body)
          expect(result).to have_key('error')
          expect(result['error']).to be_present
        end
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_goggle_cups_search_path, params: { description: search_description }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by description,' do
        let(:expected_row_count) { GogglesDb::GoggleCup.where('description LIKE ?', "%#{search_description}%").count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_goggle_cups_search_path, params: { description: search_description }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by description and team_id,' do
        let(:expected_row_count) do
          GogglesDb::GoggleCup.where('description LIKE ?', "%#{search_description}%")
                              .where(team_id: fixture_row.team_id).count
        end

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_goggle_cups_search_path,
              params: { description: search_description, team_id: fixture_row.team_id },
              headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_goggle_cups_search_path, params: { description: search_description }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_goggle_cups_search_path, params: { description: 'zzz!zzz' }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
