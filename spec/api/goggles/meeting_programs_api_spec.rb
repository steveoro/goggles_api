# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingProgramsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:meeting_program) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::MeetingProgram).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/meeting_program/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_meeting_program_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before(:each) do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_meeting_program_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end
      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_meeting_program_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_meeting_program_path(id: -1), headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON response')
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
    before(:each) do
      expect(fixture_meeting_program).to be_a(GogglesDb::MeetingProgram).and be_valid
      expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
      expect(fixture_meeting_event).to be_a(GogglesDb::MeetingEvent).and be_valid
    end

    context 'when using a valid authentication' do
      context 'without any additional filters (only meeting_id),' do
        let(:expected_row_count) { fixture_meeting.meeting_programs.count }
        before(:each) do
          get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
          expect(expected_row_count).to be_positive
        end
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'but during Maintenance mode,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_event_id,' do
        let(:expected_row_count) { fixture_meeting_event.meeting_programs.count }
        before(:each) do
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
      before(:each) { get(api_v3_meeting_programs_path, params: { meeting_id: fixture_meeting.id }, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_meeting_programs_path, params: { meeting_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
