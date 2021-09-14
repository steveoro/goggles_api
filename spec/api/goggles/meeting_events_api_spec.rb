# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingEventsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:meeting_event) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)    { FactoryBot.create(:user) }
  let(:crud_grant)   { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingEvent') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::MeetingEvent).and be_valid
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

  describe 'GET /api/v3/meeting_event/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_meeting_event_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_event_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_event_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_meeting_event_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_meeting_event_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/meeting_event/:id' do
    let(:expected_changes) do
      [
        { event_order: (rand * 20).to_i, begin_time: Time.zone.parse("2000-01-01 #{Time.zone.now.hour}:#{Time.zone.now.min}:#{Time.zone.now.sec}").to_s },
        { out_of_race: [true, false].sample, split_gender_start_list: [true, false].sample },
        { split_category_start_list: [true, false].sample, notes: FFaker::Lorem.sentence },
        { event_type_id: GogglesDb::EventType.all_eventable.sample.id },
        { heat_type_id: [GogglesDb::HeatType::HEAT_ID, GogglesDb::HeatType::SEMIFINALS_ID, GogglesDb::HeatType::FINALS_ID].sample }
      ].sample
    end

    before { expect(expected_changes).to be_an(Hash).and be_present }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_meeting_event_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_meeting_event_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meeting_events/' do
    let(:fixture_meeting_event) do
      GogglesDb::MeetingEvent.joins(:meeting, :meeting_session)
                             .includes(:meeting, :meeting_session)
                             .select('meetings.id, meeting_sessions.id')
                             .distinct.limit(500)
                             .sample
    end
    let(:fixture_meeting) { fixture_meeting_event.meeting }
    let(:fixture_meeting_session) { fixture_meeting_event.meeting_session }
    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before do
      expect(fixture_meeting_event).to be_a(GogglesDb::MeetingEvent).and be_valid
      expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
      expect(fixture_meeting_session).to be_a(GogglesDb::MeetingSession).and be_valid
    end

    context 'when using a valid authentication' do
      context 'without any additional filters (only meeting_id),' do
        let(:expected_row_count) { fixture_meeting.meeting_events.count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_session_id,' do
        let(:expected_row_count) { fixture_meeting_session.meeting_events.count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id, meeting_session_id: fixture_meeting_session.id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_meeting_events_path, params: { meeting_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
