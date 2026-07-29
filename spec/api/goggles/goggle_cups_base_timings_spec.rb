# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::GoggleCupsAPI, 'base_timings endpoint' do # rubocop:disable RSpec/SpecFilePathFormat,RSpec/DescribeMethod
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  before do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/goggle_cups/base_timings' do
    let(:default_per_page) { 50 }

    # Create a season with a championship year in the 3-year window that the view queries.
    # Current ongoing season has begin_date around Mar 2026 => championship_year = 2025.
    # The view looks for championship_year BETWEEN 2022 and 2024.
    # A season starting in Sep 2022 => championship_year = 2022 (Sep-Dec => YEAR(begin_date)).
    let(:fixture_season) do
      FactoryBot.create(:season, begin_date: Date.new(2022, 9, 1), end_date: Date.new(2023, 6, 30))
    end

    # Build a complete MIR chain that will appear in the view:
    let(:fixture_swimmer) { FactoryBot.create(:swimmer) }
    let(:fixture_team)    { FactoryBot.create(:team) }
    let(:fixture_meeting) { FactoryBot.create(:meeting, season: fixture_season) }
    let(:fixture_meeting_session) { FactoryBot.create(:meeting_session, meeting: fixture_meeting) }
    let(:fixture_event_type) do
      GogglesDb::EventsByPoolType.eventable.individuals
                                 .for_pool_type(fixture_meeting_session.pool_type)
                                 .event_length_between(50, 1500)
                                 .sample&.event_type
    end
    let(:fixture_meeting_event) do
      FactoryBot.create(:meeting_event_individual, meeting_session: fixture_meeting_session, event_type: fixture_event_type)
    end
    let(:fixture_meeting_program) do
      FactoryBot.create(:meeting_program_individual,
                        meeting_event: fixture_meeting_event,
                        gender_type: fixture_swimmer.gender_type)
    end
    let!(:fixture_mir) do
      FactoryBot.create(:meeting_individual_result,
                        swimmer: fixture_swimmer,
                        team: fixture_team,
                        meeting_program: fixture_meeting_program,
                        minutes: 1, seconds: 30, hundredths: 50,
                        disqualified: false)
    end

    let(:fixture_swimmer_id) { fixture_swimmer.id }
    let(:fixture_event_type_code) { fixture_event_type.code }

    before do
      expect(fixture_mir).to be_a(GogglesDb::MeetingIndividualResult).and be_valid
      expect(fixture_swimmer_id).to be_present
      expect(fixture_event_type_code).to be_present
    end

    context 'when using a valid authentication' do
      context 'without the required swimmer_id parameter,' do
        before { get(api_v3_goggle_cups_base_timings_path, headers: fixture_headers) }

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
          get(api_v3_goggle_cups_base_timings_path, params: { swimmer_id: fixture_swimmer_id }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a valid swimmer_id,' do
        before { get(api_v3_goggle_cups_base_timings_path, params: { swimmer_id: fixture_swimmer_id }, headers: fixture_headers) }

        it_behaves_like('successful multiple, single-page response without pagination links in headers')
      end

      context 'when filtering by swimmer_id and event_type_code,' do
        before do
          get(api_v3_goggle_cups_base_timings_path,
              params: { swimmer_id: fixture_swimmer_id, event_type_code: fixture_event_type_code },
              headers: fixture_headers)
        end

        it_behaves_like('successful multiple, single-page response without pagination links in headers')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_goggle_cups_base_timings_path, params: { swimmer_id: 1 }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing swimmer_id,' do
      before do
        expect(GogglesDb::Swimmer.exists?(0)).to be false
        get(api_v3_goggle_cups_base_timings_path, params: { swimmer_id: 0 }, headers: fixture_headers)
      end

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
