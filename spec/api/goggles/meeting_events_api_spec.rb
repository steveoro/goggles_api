# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingEventsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:meeting_event) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::MeetingEvent).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/meeting_event/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_meeting_event_path(id: fixture_row.id), headers: fixture_headers) }
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_row.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_meeting_event_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_meeting_event_path(id: -1), headers: fixture_headers) }
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
    before(:each) do
      expect(fixture_meeting_event).to be_a(GogglesDb::MeetingEvent).and be_valid
      expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
      expect(fixture_meeting_session).to be_a(GogglesDb::MeetingSession).and be_valid
    end

    context 'when using a valid authentication' do
      context 'without any additional filters,' do
        let(:expected_row_count) { fixture_meeting.meeting_events.count }

        before(:each) { get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers) }
        it 'is successful' do
          expect(expected_row_count).to be_positive
          expect(response).to be_successful
        end

        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by a specific meeting_session_id,' do
        let(:expected_row_count) { fixture_meeting_session.meeting_events.count }

        before(:each) do
          expect(expected_row_count).to be_positive
          get(
            api_v3_meeting_events_path,
            params: {
              meeting_id: fixture_meeting.id,
              meeting_session_id: fixture_meeting_session.id
            },
            headers: fixture_headers
          )
        end

        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_meeting_events_path, params: { meeting_id: fixture_meeting.id }, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_meeting_events_path, params: { meeting_id: -1 }, headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
