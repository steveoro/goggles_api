# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingReservationsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:mrr_new) do
    mevent = FactoryBot.create(:meeting_event_relay, meeting_session: fixture_row.meeting.meeting_sessions.first)
    FactoryBot.create(:meeting_relay_reservation, meeting_event: mevent, meeting_reservation: fixture_row)
  end
  let(:mer_new) do
    mevent = FactoryBot.create(:meeting_event_individual, meeting_session: fixture_row.meeting.meeting_sessions.first)
    FactoryBot.create(:meeting_event_reservation, meeting_event: mevent, meeting_reservation: fixture_row)
  end
  let(:mer_first) { fixture_row.meeting_event_reservations.first }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingReservation') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:mer_first) { fixture_row.meeting_event_reservations.first }
  let(:mer_new) do
    mevent = FactoryBot.create(:meeting_event_individual, meeting_session: fixture_row.meeting.meeting_sessions.first)
    FactoryBot.create(:meeting_event_reservation, meeting_event: mevent, meeting_reservation: fixture_row)
  end
  let(:mrr_new) do
    mevent = FactoryBot.create(:meeting_event_relay, meeting_session: fixture_row.meeting.meeting_sessions.first)
    FactoryBot.create(:meeting_relay_reservation, meeting_event: mevent, meeting_reservation: fixture_row)
  end
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:meeting_event_reservation).meeting_reservation }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::MeetingReservation).and be_valid
    expect(fixture_row.meeting_event_reservations).not_to be_empty
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/meeting_reservation/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_meeting_reservation_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_meeting_reservation_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_meeting_reservation_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_meeting_reservation_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end

  describe 'PUT /api/v3/meeting_reservation/:id' do
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(mer_first).to be_a(GogglesDb::MeetingEventReservation).and be_valid
      expect(mer_new).to be_a(GogglesDb::MeetingEventReservation).and be_valid
      expect(mrr_new).to be_a(GogglesDb::MeetingRelayReservation).and be_valid
      expect(fixture_row.meeting_event_reservations.count).to be >= 2
      # 1 relay reservation is enough for the purpose of this context:
      expect(fixture_row.meeting_relay_reservations.count).to be_positive
    end

    context 'when using valid parameters,' do
      # For this context, having to deal with associated sub-entities updates, we'll
      # keep the sub-entities changes in separate cases, so that the checking logic is
      # simpler.
      let(:expected_changes) do
        [
          { not_coming: [true, false].sample, confirmed: [true, false].sample, notes: FFaker::BaconIpsum.phrase },
          {
            events: [
              {
                id: mer_first.id,
                minutes: (0..3).to_a.sample, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 59) % 59).to_i,
                accepted: [true, false].sample
              },
              {
                id: mer_new.id,
                minutes: (0..2).to_a.sample, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 59) % 59).to_i,
                accepted: [true, false].sample
              }
            ],
            relays: [
              { id: mrr_new.id, accepted: [true, false].sample, notes: FFaker::BaconIpsum.phrase[0..48] }
            ]
          }
        ].sample
      end

      before { expect(expected_changes).to be_an(Hash).and be_present }

      context 'with an account having CRUD grants' do
        before { put(api_v3_meeting_reservation_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        # Private helper for this test to simplify checking logic
        def check_expected_subentity_changes_in(updated_row, sub_sym_key, sub_klass)
          return unless expected_changes.key?(sub_sym_key)

          expected_changes[sub_sym_key].each do |expected_sub_changes|
            updated_sub_row = updated_row.send("meeting_#{sub_sym_key.to_s.singularize}_reservations").find_by(id: expected_sub_changes[:id])
            expect(updated_sub_row).to be_a(sub_klass).and be_valid
            expected_sub_changes.each do |key, value|
              expect(updated_sub_row.send(key)).to eq(value)
            end
          end
        end

        it_behaves_like('a successful request that has positive usage stats')

        it 'sets the user_id of the parent row to caller user_id' do
          updated_row = fixture_row.reload
          expect(updated_row.user_id).to eq(crud_user.id)
        end

        it 'updates the row and returns true' do
          expect(response.body).to eq('true')
          updated_row = fixture_row.reload
          # Deal with specific sub-entity (children) cases:
          check_expected_subentity_changes_in(updated_row, :events, GogglesDb::MeetingEventReservation)
          check_expected_subentity_changes_in(updated_row, :relays, GogglesDb::MeetingRelayReservation)
          # Deal with parent updates:
          if !expected_changes.key?(:events) && !expected_changes.key?(:relays)
            expected_changes.each do |key, value|
              expect(updated_row.send(key)).to eq(value)
            end
          end
        end
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_reservation_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_meeting_reservation_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using incorrect children IDs,' do # (may have successful parent updates with failing children's)
      let(:invalid_mer_id) {  GogglesDb::MeetingEventReservation.select(:id).last.id + 10 }
      let(:invalid_mrr_id) {  GogglesDb::MeetingRelayReservation.select(:id).last.id + 10 }
      let(:expected_changes) do
        [
          {
            events: [
              { id: -1, hundredths: ((rand * 59) % 59).to_i, accepted: [true, false].sample },
              { id: invalid_mer_id, minutes: [0, 1, 2].sample, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 59) % 59).to_i }
            ]
          },
          {
            relays: [
              { id: -1, accepted: [true, false].sample },
              { id: invalid_mrr_id, notes: FFaker::BaconIpsum.phrase[0..48] }
            ]
          }
        ].sample
      end

      before { expect(expected_changes).to be_an(Hash).and be_present }

      context 'with an account having CRUD grants' do
        before { put(api_v3_meeting_reservation_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        # (This is successful because incorrect children IDs are just ignored)
        it_behaves_like('a successful request that has positive usage stats')

        it 'sets the user_id of the parent row to caller user_id anyway' do
          updated_row = fixture_row.reload
          expect(updated_row.user_id).to eq(crud_user.id)
        end
      end
    end

    context 'when using an invalid JWT,' do
      before do
        put(
          api_v3_meeting_reservation_path(id: fixture_row.id),
          params: { confirmed: true },
          headers: { 'Authorization' => 'you wish!' }
        )
      end

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        put(
          api_v3_meeting_reservation_path(id: -1),
          params: { confirmed: true },
          headers: crud_headers
        )
      end

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/meeting_reservation' do
    # To assure that the selected meeting has indeed events, we'll start from the
    # events themselves; then, proceed to create a new random badge in order to avoid
    # conflict with any existing reservations:
    let(:fixture_meeting) do
      mev = GogglesDb::MeetingEvent.limit(200).sample
      mev.meeting
    end
    let(:fixture_season)   { fixture_meeting.season }
    let(:fixture_team_aff) { fixture_season.team_affiliations.sample }
    let(:fixture_category) { fixture_season.category_types.sample }
    let(:fixture_swimmer)  { FactoryBot.create(:swimmer) }
    let(:fixture_badge) do
      FactoryBot.create(
        :badge,
        swimmer: fixture_swimmer,
        category_type: fixture_category,
        team_affiliation: fixture_team_aff,
        season: fixture_season,
        team: fixture_team_aff.team
      )
    end
    let(:valid_parameters) { { badge_id: fixture_badge.id, meeting_id: fixture_meeting.id } }

    # Make sure domain is coherent with expected context:
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')

      expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
      expect(fixture_meeting.meeting_events.count).to be_positive
      expect(fixture_season).to be_a(GogglesDb::Season).and be_valid
      expect(fixture_team_aff).to be_a(GogglesDb::TeamAffiliation).and be_valid
      expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
      expect(fixture_category).to be_a(GogglesDb::CategoryType).and be_valid
      expect(fixture_badge).to be_a(GogglesDb::Badge).and be_valid
      expect(valid_parameters).to be_an(Hash).and have_key(:badge_id).and have_key(:meeting_id)
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_meeting_reservation_path, params: valid_parameters, headers: crud_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        # Custom check due the specific structure of the returned object:
        it 'updates the row and returns the result msg and the new row as JSON' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg').and have_key('new')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
          expect(result['new']).to have_key('id').and have_key('badge_id').and have_key('meeting_id')
          expect(result['new']['badge_id'].to_i).to eq(fixture_badge.id)
          expect(result['new']['meeting_id'].to_i).to eq(fixture_meeting.id)
        end
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_meeting_reservation_path, params: valid_parameters, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_meeting_reservation_path, params: valid_parameters, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_meeting_reservation_path, params: valid_parameters, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before { post(api_v3_meeting_reservation_path, params: { badge_id: -1, meeting_id: fixture_meeting.id }, headers: crud_headers) }

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

  describe 'DELETE /api/v3/meeting_reservation/:id' do
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:meeting_reservation) }

      before { expect(deletable_row).to be_a(GogglesDb::MeetingReservation).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_meeting_reservation_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_meeting_reservation_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_meeting_reservation_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_meeting_reservation_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_meeting_reservation_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meeting_reservations/' do
    context 'when using a valid authentication' do
      let(:fixture_sample) { GogglesDb::MeetingReservation.limit(200).sample } # (more than 3K+ M.Reservations should be available in the test DB)
      let(:default_per_page) { 25 }

      before do
        expect(fixture_sample).to be_a(GogglesDb::MeetingReservation).and be_valid
        expect(fixture_sample.meeting_event_reservations.count).to be_positive
      end

      context 'without any filters,' do
        before { get(api_v3_meeting_reservations_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_reservations_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_id,' do
        let(:expected_row_count) { GogglesDb::MeetingReservation.where(meeting_id: fixture_sample.meeting_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_reservations_path, params: { meeting_id: fixture_sample.meeting_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific team_id,' do
        # (Team ID 1 is expected to have more than 2K swimmer reservations in the test database)
        before { get(api_v3_meeting_reservations_path, params: { team_id: 1 }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific swimmer_id,' do
        let(:expected_row_count) { GogglesDb::MeetingReservation.where(swimmer_id: fixture_sample.swimmer_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_reservations_path, params: { swimmer_id: fixture_sample.swimmer_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific badge_id,' do
        let(:expected_row_count) { GogglesDb::MeetingReservation.where(badge_id: fixture_sample.badge_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_reservations_path, params: { badge_id: fixture_sample.badge_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meeting_reservations_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_meeting_reservations_path, params: { swimmer_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
