# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingProgramsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:meeting_program) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)    { FactoryBot.create(:user) }
  let(:crud_grant)   { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingProgram') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::MeetingProgram).and be_valid
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

  describe 'GET /api/v3/meeting_program/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_meeting_program_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_program_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_program_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_meeting_program_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_meeting_program_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/meeting_program/:id' do
    let(:expected_changes) do
      [
        { event_order: (rand * 20).to_i, begin_time: Time.zone.parse("2000-01-01 #{Time.zone.now.hour}:#{Time.zone.now.min}:#{Time.zone.now.sec}").to_s },
        { category_type_id: GogglesDb::CategoryType.eventable.last(100).sample.id },
        { gender_type_id: [GogglesDb::GenderType::MALE_ID, GogglesDb::GenderType::FEMALE_ID].sample },
        { out_of_race: [true, false].sample, autofilled: [true, false].sample },
        { meeting_event_id: GogglesDb::MeetingEvent.last(100).sample.id },
        # TODO: add the following after the next GogglesDb life cycle (w/ standard_timing migration fix)
        # { time_standard_id: GogglesDb::StandardTiming.first(100).sample.id },
        { pool_type_id: [GogglesDb::PoolType::MT_25_ID, GogglesDb::PoolType::MT_50_ID].sample }
      ].sample
    end

    before { expect(expected_changes).to be_an(Hash).and be_present }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_meeting_program_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_meeting_program_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meeting_programs/' do
    let(:fixture_meeting_program) do
      GogglesDb::MeetingProgram.joins(:meeting).includes(:meeting)
                               .select('meetings.id')
                               .distinct.limit(500)
                               .sample
    end
    let(:fixture_meeting) { fixture_meeting_program.meeting }
    let(:fixture_meeting_event) { fixture_meeting_program.meeting_event }
    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before do
      expect(fixture_meeting_program).to be_a(GogglesDb::MeetingProgram).and be_valid
      expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
      expect(fixture_meeting_event).to be_a(GogglesDb::MeetingEvent).and be_valid
    end

    context 'when using a valid authentication' do
      context 'without any additional filters (only meeting_id),' do
        let(:expected_row_count) { fixture_meeting.meeting_programs.count }

        before do
          get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
          expect(expected_row_count).to be_positive
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_event_id,' do
        let(:expected_row_count) { fixture_meeting_event.meeting_programs.count }

        before do
          expect(expected_row_count).to be_positive
          get(
            api_v3_meeting_programs_path,
            params: { meeting_id: fixture_meeting.id, meeting_event_id: fixture_meeting_event.id },
            headers: fixture_headers
          )
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_meeting_programs_path, params: { meeting_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
