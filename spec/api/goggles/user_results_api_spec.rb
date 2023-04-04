# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::UserResultsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:user_result) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'UserResult') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::UserResult).and be_valid
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

  describe 'GET /api/v3/user_result/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_user_result_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_result_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_result_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_user_result_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_user_result_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/user_result/:id' do
    let(:new_row) { FactoryBot.create(:user_result) }
    let(:expected_changes) do
      [
        { user_id: new_row.user_id, user_workshop_id: new_row.user_workshop_id },
        { swimmer_id: new_row.swimmer_id },
        { pool_type_id: new_row.pool_type_id, category_type_id: new_row.category_type_id },
        { event_type_id: new_row.event_type_id },
        { event_date: Time.zone.today, standard_points: (500.0 + (rand * 500.0)).round(2), meeting_points: 0.0 },
        { rank: (rand * 30).to_i, reaction_time: (rand + 0.07).round(2) },
        { disqualified: [true, false].sample, disqualification_code_type_id: [GogglesDb::DisqualificationCodeType.all.sample.id, nil].sample },
        { minutes: 0, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 59) % 59).to_i }
      ].sample
    end

    before do
      expect(new_row).to be_a(GogglesDb::UserResult).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_user_result_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_user_result_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_result_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_result_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_user_result_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_user_result_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/user_result' do
    let(:built_row) do
      FactoryBot.build(
        :user_result,
        user_id: GogglesDb::User.first(50).sample.id,
        user_workshop_id: FactoryBot.create(:user_workshop).id,
        swimmer_id: GogglesDb::Swimmer.first(150).sample.id,
        swimming_pool_id: GogglesDb::SwimmingPool.first(150).sample.id,
        category_type_id: GogglesDb::CategoryType.eventable.individuals.sample.id,
        pool_type_id: GogglesDb::PoolType.all_eventable.sample.id,
        event_type_id: GogglesDb::EventsByPoolType.eventable.individuals.sample.event_type_id
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::UserResult).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_user_result_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_result_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_result_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_user_result_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_user_result_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    # NOTE: for legacy reasons results were supposed to be created even with a lot of invalid parameters
    #       (negative or null IDs), so for the moment we'll just check the "missing" outcome.
    context 'when calling with missing parameters,' do
      before do
        post(
          api_v3_user_result_path,
          params: {
            user_id: built_row.user_id,
            user_workshop_id: built_row.user_workshop_id,
            # (no event_date & pool_type)
            event_type_id: 1,
            category_type_id: 1
          },
          headers: crud_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a specific error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq('event_date is missing, pool_type_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/user_result/:id' do
    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:user_result) }

      before { expect(deletable_row).to be_a(GogglesDb::UserResult).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_user_result_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_result_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_result_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_user_result_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_user_result_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_user_result_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/user_results/' do
    # Add some fixtures to the test Domain once, only if missing:
    # (These are supposed to remain there, and this is why an "after(:all)" clearing block
    # is totally missing here)
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
        before { get(api_v3_user_results_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_results_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_results_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      %i[user_id user_workshop_id pool_type_id event_type_id category_type_id swimmer_id].each do |filter_sym|
        context "when filtering by a specific #{filter_sym}," do
          let(:filter_id) { GogglesDb::UserResult.all.limit(200).sample.send(filter_sym) }
          let(:expected_row_count) { GogglesDb::UserResult.where(filter_sym => filter_id).count }
          # Make sure the Domain contains the expected seeds:

          before do
            expect(filter_id).to be_positive
            expect(expected_row_count).to be_positive
            get(api_v3_user_results_path, params: { filter_sym => filter_id }, headers: fixture_headers)
          end

          it_behaves_like('successful multiple row response either with OR without pagination links')
        end
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_user_results_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_user_results_path, params: { swimmer_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
