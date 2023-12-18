# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::RelayLapsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'RelayLap') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:relay_lap) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::RelayLap).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/relay_lap/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_relay_lap_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_relay_lap_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_relay_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_relay_lap_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end

  describe 'PUT /api/v3/relay_lap/:id' do
    let(:new_relay_lap) do
      mrs = FactoryBot.create(:meeting_relay_swimmer)
      FactoryBot.build(
        :relay_lap,
        meeting_relay_result_id: mrs.meeting_relay_result_id,
        meeting_relay_swimmer_id: mrs.id,
        swimmer_id: mrs.swimmer_id,
        team_id: mrs.team.id
      )
    end
    let(:expected_changes) do
      [
        { meeting_relay_result_id: new_relay_lap.meeting_relay_result_id },
        { meeting_relay_swimmer_id: new_relay_lap.meeting_relay_swimmer_id },
        { team_id: new_relay_lap.team_id, swimmer_id: new_relay_lap.swimmer_id },
        { minutes: 0, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 100) % 100).to_i },
        { minutes_from_start: ((rand * 4) % 4).to_i, seconds_from_start: ((rand * 59) % 59).to_i, hundredths_from_start: ((rand * 100) % 100).to_i },
        { position: (rand * 10).to_i, reaction_time: (rand + 0.07).round(2) }
      ].sample
    end

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_relay_lap).to be_a(GogglesDb::RelayLap).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_relay_lap_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_relay_lap_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_relay_lap_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_relay_lap_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_relay_lap_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/relay_lap' do
    let(:built_row) do
      mrs = FactoryBot.create(:meeting_relay_swimmer)
      FactoryBot.build(
        :relay_lap,
        meeting_relay_swimmer_id: mrs.id,
        swimmer_id: mrs.swimmer_id,
        team_id: mrs.team.id
      )
    end

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::RelayLap).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_relay_lap_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_relay_lap_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_relay_lap_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_relay_lap_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when calling with missing parameters,' do
      before do
        post(
          api_v3_relay_lap_path,
          params: built_row.attributes.except('swimmer_id'),
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

  describe 'DELETE /api/v3/relay_lap/:id' do
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:relay_lap) }

      before { expect(deletable_row).to be_a(GogglesDb::RelayLap).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_relay_lap_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_relay_lap_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_relay_lap_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_relay_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_relay_lap_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/relay_laps/' do
    context 'when using a valid authentication' do
      let(:fixture_mrr_id) do
        FactoryBot.create_list(:relay_lap, 10)
        GogglesDb::RelayLap.last(10).sample.meeting_relay_result_id
      end
      let(:fixture_mrs) do
        FactoryBot.create_list(:relay_lap, 10)
        GogglesDb::RelayLap.includes(:meeting_relay_swimmer)
                           .joins(:meeting_relay_swimmer).last(100).sample
                           .meeting_relay_swimmer
      end
      let(:default_per_page) { 25 }
      # Make sure the Domain contains the expected seeds:

      before do
        expect(fixture_mrr_id).to be_positive
        expect(fixture_mrs).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid
      end

      context 'without any filters,' do
        let(:expected_row_count) { GogglesDb::RelayLap.count }

        before { get(api_v3_relay_laps_path, headers: fixture_headers) }

        # Currently there are no preseeded fixture rows, so we'll definitely fall short of 25
        # (given the created fixtures above)
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_relay_laps_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_relay_result_id,' do
        let(:expected_row_count) { GogglesDb::RelayLap.where(meeting_relay_result_id: fixture_mrr_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_relay_laps_path, params: { meeting_relay_result_id: fixture_mrr_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific meeting_relay_swimmer_id,' do
        let(:expected_row_count) { GogglesDb::RelayLap.where(meeting_relay_swimmer_id: fixture_mrs.id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_relay_laps_path, params: { meeting_relay_swimmer_id: fixture_mrs.id }, headers: fixture_headers)
        end
        # This will support even just 1 result row:

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific swimmer_id,' do
        let(:expected_row_count) { GogglesDb::RelayLap.where(swimmer_id: fixture_mrs.swimmer_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_relay_laps_path, params: { swimmer_id: fixture_mrs.swimmer_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific team_id,' do
        let(:expected_row_count) { GogglesDb::RelayLap.where(team_id: fixture_mrs.team.id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_relay_laps_path, params: { team_id: fixture_mrs.team.id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_relay_laps_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_relay_laps_path, params: { team_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
