# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::StandardTimingsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:standard_timing) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'StandardTiming') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::StandardTiming).and be_valid
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

  describe 'GET /api/v3/standard_timing/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_standard_timing_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_standard_timing_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_standard_timing_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_standard_timing_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_standard_timing_path(id: -1), headers: fixture_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/standard_timing/:id' do
    let(:built_row) { FactoryBot.build(:standard_timing, season_id: FactoryBot.create(:season).id) }
    let(:expected_changes) do
      [
        { minutes: built_row.minutes, seconds: built_row.seconds, hundredths: built_row.hundredths },
        { gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id },
        { pool_type_id: GogglesDb::PoolType.all_eventable.sample.id },
        { event_type_id: GogglesDb::StandardTiming.includes(:event_type).joins(:event_type).select(:event_type_id).distinct.first(20).sample.event_type_id },
        { category_type_id: GogglesDb::CategoryType.eventable.individuals.last(100).sample.id },
        { season_id: built_row.season_id }
      ].sample
    end

    before do
      expect(built_row).to be_a(GogglesDb::StandardTiming).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_standard_timing_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_standard_timing_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/standard_timing' do
    # Make sure parameters for the POST include all required attributes:
    let(:built_row) do
      FactoryBot.build(
        :standard_timing,
        gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id,
        pool_type_id: GogglesDb::PoolType.all_eventable.sample.id,
        event_type_id: GogglesDb::EventType.all_eventable.sample.id,
        category_type_id: GogglesDb::CategoryType.eventable.individuals.last(100).sample.id,
        season_id: FactoryBot.create(:season).id
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::StandardTiming).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_standard_timing_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_standard_timing_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_standard_timing_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_standard_timing_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_standard_timing_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_standard_timing_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
        post(
          api_v3_standard_timing_path,
          params: {
            minutes: 0,
            seconds: 0,
            hundredths: 0,
            gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id,
            pool_type_id: GogglesDb::PoolType.all_eventable.sample.id,
            event_type_id: GogglesDb::EventType.all_eventable.sample.id,
            category_type_id: GogglesDb::CategoryType.eventable.individuals.last(100).sample.id,
            season_id: -1
          },
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

  describe 'DELETE /api/v3/standard_timing/:id' do
    let(:deletable_row) { FactoryBot.create(:standard_timing) }

    before { expect(deletable_row).to be_a(GogglesDb::StandardTiming).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_standard_timing_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_standard_timing_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_standard_timing_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_standard_timing_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_standard_timing_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_standard_timing_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_standard_timing_path(id: -1), headers: admin_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/standard_timings/' do
    let(:default_per_page) { 25 }

    context 'without any filters (with valid authentication),' do
      before { get(api_v3_standard_timings_path, headers: fixture_headers) }

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_standard_timings_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_standard_timings_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific season_id (with valid authentication),' do
      let(:fixture_season_id) { [152, 162, 172, 182, 192].sample }
      let(:expected_row_count) { GogglesDb::StandardTiming.where(season_id: fixture_season_id).count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_standard_timings_path, params: { season_id: fixture_season_id }, headers: fixture_headers)
      end

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when filtering by a specific gender_type_id (with valid authentication),' do
      let(:fixture_gender_type_id) { GogglesDb::GenderType.send(%w[male female].sample).id }
      let(:expected_row_count) { GogglesDb::StandardTiming.where(gender_type_id: fixture_gender_type_id).count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_standard_timings_path, params: { gender_type_id: fixture_gender_type_id }, headers: fixture_headers)
      end

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when filtering by a specific pool_type_id (with valid authentication),' do
      let(:fixture_pool_type_id) { GogglesDb::PoolType.all_eventable.sample.id }
      let(:expected_row_count) { GogglesDb::StandardTiming.where(pool_type_id: fixture_pool_type_id).count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_standard_timings_path, params: { pool_type_id: fixture_pool_type_id }, headers: fixture_headers)
      end

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when filtering by a specific event_type_id (with valid authentication),' do
      let(:fixture_event_type_id) do
        GogglesDb::StandardTiming.includes(:event_type).joins(:event_type)
                                 .distinct(:event_type_id)
                                 .pluck(:event_type_id)
                                 .uniq.first(50)
                                 .sample
      end
      let(:expected_row_count) { GogglesDb::StandardTiming.where(event_type_id: fixture_event_type_id).count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_standard_timings_path, params: { event_type_id: fixture_event_type_id }, headers: fixture_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific category_type_id (with valid authentication),' do
      let(:fixture_category_type_id) do
        GogglesDb::StandardTiming.includes(:category_type).joins(:category_type)
                                 .distinct(:category_type_id)
                                 .pluck(:category_type_id)
                                 .uniq.last(100)
                                 .sample
      end
      let(:expected_row_count) { GogglesDb::StandardTiming.where(category_type_id: fixture_category_type_id).count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_standard_timings_path, params: { category_type_id: fixture_category_type_id }, headers: fixture_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_standard_timings_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_standard_timings_path, params: { season_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
