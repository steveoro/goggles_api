# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingRelayResultsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:meeting_relay_result_with_swimmers) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::MeetingRelayResult).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/meeting_relay_result/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_meeting_relay_result_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_meeting_relay_result_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_meeting_relay_result_path(id: -1), headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingRelayResult') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  describe 'PUT /api/v3/meeting_relay_result/:id' do
    let(:new_badge) { FactoryBot.create(:badge) }
    let(:expected_changes) do
      [
        { relay_code: FFaker::Lorem.word, team_id: new_badge.team_id, team_affiliation_id: new_badge.team_affiliation_id },
        { rank: (rand * 10).to_i, standard_points: (500.0 + rand * 500.0).round(2), meeting_points: 0.0 },
        { rank: (rand * 10).to_i, meeting_points: (500.0 + rand * 500.0).round(2), reaction_time: (rand + 0.07).round(2) },
        { disqualified: [true, false].sample, disqualification_code_type_id: [GogglesDb::DisqualificationCodeType.all.sample.id, nil].sample },
        { rank: (rand * 10).to_i, minutes: 0, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 100) % 100).to_i },
        { entry_minutes: ((rand * 4) % 4).to_i, entry_seconds: ((rand * 59) % 59).to_i, entry_hundredths: ((rand * 100) % 100).to_i },
        { out_of_race: [true, false].sample }
      ].sample
    end
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_badge).to be_a(GogglesDb::Badge).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before(:each) { put(api_v3_meeting_relay_result_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having the proper grants,' do
        before(:each) { put(api_v3_meeting_relay_result_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_meeting_relay_result_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { put(api_v3_meeting_relay_result_path(id: -1), params: expected_changes, headers: crud_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/meeting_relay_result' do
    let(:built_row) { FactoryBot.build(:meeting_relay_result) }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::MeetingRelayResult).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before(:each) { post(api_v3_meeting_relay_result_path, params: built_row.attributes, headers: crud_headers) }
        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_meeting_relay_result_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_meeting_relay_result_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    # NOTE: for legacy reasons MRRs were supposed to be created even with a lot of invalid parameters
    #       (negative or null IDs), so for the moment we'll just check the "missing" outcome.
    context 'when using missing parameters,' do
      before(:each) do
        post(
          api_v3_meeting_relay_result_path,
          params: { meeting_program_id: built_row.meeting_program_id, team_affiliation_id: built_row.team_affiliation_id },
          headers: crud_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with a specific error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq('team_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/meeting_relay_result/:id' do
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end
    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:meeting_relay_result) }
      before(:each) { expect(deletable_row).to be_a(GogglesDb::MeetingRelayResult).and be_valid }

      context 'with an account having CRUD grants,' do
        before(:each) { delete(api_v3_meeting_relay_result_path(id: deletable_row.id), headers: crud_headers) }
        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account not having the proper grants,' do
        before(:each) { delete(api_v3_meeting_relay_result_path(id: fixture_row.id), headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { delete(api_v3_meeting_relay_result_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { delete(api_v3_meeting_relay_result_path(id: -1), headers: crud_headers) }
      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meeting_relay_results/' do
    context 'when using a valid authentication' do
      let(:fixture_mprg_id) { GogglesDb::MeetingRelayResult.last(200).sample.meeting_program_id }
      let(:default_per_page) { 25 }
      let(:expected_row_count) { GogglesDb::MeetingRelayResult.where(meeting_program_id: fixture_mprg_id).count }
      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_mprg_id).to be_positive
        expect(expected_row_count).to be_positive
      end

      context 'without any filters,' do
        before(:each) { get(api_v3_meeting_relay_results_path, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific meeting_program_id,' do
        before(:each) { get(api_v3_meeting_relay_results_path, params: { meeting_program_id: fixture_mprg_id }, headers: fixture_headers) }
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific team_id,' do
        # (Team ID 1 is expected to have definitely more than 25 entries in the test database)
        before(:each) { get(api_v3_meeting_relay_results_path, params: { team_id: 1 }, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_meeting_relay_results_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_meeting_relay_results_path, params: { team_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
