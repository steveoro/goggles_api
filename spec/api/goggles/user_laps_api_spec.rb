# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::UserLapsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:user_lap) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'UserLap') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::UserLap).and be_valid
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

  describe 'GET /api/v3/user_lap/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_user_lap_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_lap_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_lap_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_user_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_user_lap_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/user_lap/:id' do
    let(:built_row) do
      FactoryBot.build(
        :user_lap,
        user_result_id: FactoryBot.create(:user_result).id,
        swimmer_id: GogglesDb::Swimmer.first(150).sample.id
      )
    end
    let(:expected_changes) do
      [
        { user_result_id: built_row.user_result_id, swimmer_id: built_row.swimmer_id },
        { minutes: 0, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 100) % 100).to_i },
        { minutes_from_start: ((rand * 4) % 4).to_i, seconds_from_start: ((rand * 59) % 59).to_i, hundredths_from_start: ((rand * 100) % 100).to_i },
        { position: (rand * 10).to_i, reaction_time: (rand + 0.07).round(2) }
      ].sample
    end

    before do
      expect(built_row).to be_a(GogglesDb::UserLap).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_user_lap_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_user_lap_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_lap_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_lap_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_user_lap_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_user_lap_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/user_lap' do
    let(:built_row) do
      FactoryBot.build(
        :user_lap,
        user_result_id: FactoryBot.create(:user_result).id,
        swimmer_id: GogglesDb::Swimmer.first(150).sample.id
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::UserLap).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_user_lap_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_lap_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_lap_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_user_lap_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_user_lap_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when calling with missing parameters,' do
      before do
        post(
          api_v3_user_lap_path,
          params: built_row.attributes.reject { |key, _val| key == 'swimmer_id' },
          headers: crud_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a specific error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq('swimmer_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/user_lap/:id' do
    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:user_lap) }

      before { expect(deletable_row).to be_a(GogglesDb::UserLap).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_user_lap_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_lap_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_lap_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_user_lap_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_user_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_user_lap_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/user_laps/' do
    # Add some fixtures to the test Domain once, only if missing:
    before(:all) do
      if (GogglesDb::UserWorkshop.count < 10) || (GogglesDb::UserResult.count < 40) ||
         (GogglesDb::UserLap.count < 80)
        FactoryBot.create_list(:workshop_with_results_and_laps, 5)
        fixture_user_id = GogglesDb::UserWorkshop.all.limit(20).sample.user.id
        expect(fixture_user_id).to be_positive
        FactoryBot.create_list(:workshop_with_results_and_laps, 5, user_id: fixture_user_id)
      end
    end

    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before do
      expect(GogglesDb::UserWorkshop.count).to be >= 10
      expect(GogglesDb::UserResult.count).to be >= 40
      expect(GogglesDb::UserLap.count).to be >= 80
    end

    context 'when using a valid authentication' do
      context 'without any filters,' do
        before { get(api_v3_user_laps_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_laps_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_laps_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      %i[user_result_id swimmer_id].each do |filter_sym|
        context "when filtering by a specific #{filter_sym}," do
          let(:filter_id) { GogglesDb::UserLap.all.limit(200).sample.send(filter_sym) }
          let(:expected_row_count) { GogglesDb::UserLap.where(filter_sym => filter_id).count }
          # Make sure the Domain contains the expected seeds:

          before do
            expect(filter_id).to be_positive
            expect(expected_row_count).to be_positive
            get(api_v3_user_laps_path, params: { filter_sym => filter_id }, headers: fixture_headers)
          end

          it_behaves_like('successful multiple row response either with OR without pagination links')
        end
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_user_laps_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_user_laps_path, params: { swimmer_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
