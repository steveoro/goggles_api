# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingRelaySwimmersAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:new_built_row) { FactoryBot.build(:meeting_relay_swimmer) }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingRelaySwimmer') }
  #-- -------------------------------------------------------------------------
  #++

  let(:crud_user) { FactoryBot.create(:user) }
  #-- -------------------------------------------------------------------------
  #++

  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'MeetingRelaySwimmer') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:new_built_row) { FactoryBot.build(:meeting_relay_swimmer) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:meeting_relay_swimmer) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/meeting_relay_swimmer/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_meeting_relay_swimmer_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_meeting_relay_swimmer_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end

  describe 'PUT /api/v3/meeting_relay_swimmer/:id' do
    let(:expected_changes) do
      [
        { meeting_relay_result_id: new_built_row.meeting_relay_result_id, swimmer_id: new_built_row.swimmer_id },
        { stroke_type_id: new_built_row.stroke_type_id, badge_id: new_built_row.badge_id, swimmer_id: new_built_row.swimmer_id },
        { minutes: new_built_row.minutes, seconds: new_built_row.seconds, hundredths: new_built_row.hundredths },
        { relay_order: (1..4).to_a.sample, reaction_time: (rand + 0.07).round(2) }
      ].sample
    end

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_built_row).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_meeting_relay_swimmer_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/meeting_relay_swimmer' do
    let(:built_row) { FactoryBot.build(:meeting_relay_swimmer) }

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_meeting_relay_swimmer_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_meeting_relay_swimmer_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_meeting_relay_swimmer_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_meeting_relay_swimmer_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when calling with missing parameters,' do
      before do
        post(
          api_v3_meeting_relay_swimmer_path,
          params: built_row.attributes.except('stroke_type_id'),
          headers: crud_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a specific error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq('stroke_type_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/meeting_relay_swimmer/:id' do
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:meeting_relay_swimmer) }

      before { expect(deletable_row).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_meeting_relay_swimmer_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_meeting_relay_swimmer_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_meeting_relay_swimmer_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_meeting_relay_swimmer_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meeting_relay_swimmers/' do
    context 'when using a valid authentication' do
      let(:fixture_mrs) { GogglesDb::MeetingRelaySwimmer.last(200).sample }
      let(:fixture_mrr) do
        GogglesDb::MeetingRelaySwimmer.includes(:meeting_relay_result)
                                      .joins(:meeting_relay_result)
                                      .last(200).sample
                                      .meeting_relay_result
      end
      let(:default_per_page) { 25 }
      # Make sure the Domain contains the expected seeds:

      before do
        expect(fixture_mrs).to be_a(GogglesDb::MeetingRelaySwimmer).and be_valid
        expect(fixture_mrr).to be_a(GogglesDb::MeetingRelayResult).and be_valid
      end

      context 'without any filters,' do
        before { get(api_v3_meeting_relay_swimmers_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meeting_relay_swimmers_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_relay_result_id,' do
        let(:expected_row_count) { GogglesDb::MeetingRelaySwimmer.where(meeting_relay_result_id: fixture_mrr.id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_relay_swimmers_path, params: { meeting_relay_result_id: fixture_mrr.id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific badge_id,' do
        let(:expected_row_count) { GogglesDb::MeetingRelaySwimmer.where(badge_id: fixture_mrs.badge_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_relay_swimmers_path, params: { badge_id: fixture_mrs.badge_id }, headers: fixture_headers)
        end
        # This will support even just 1 result row:

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific swimmer_id,' do
        let(:expected_row_count) { GogglesDb::MeetingRelaySwimmer.where(swimmer_id: fixture_mrs.swimmer_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meeting_relay_swimmers_path, params: { swimmer_id: fixture_mrs.swimmer_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific stroke_type_id,' do
        # (stroke_type_id ID 1 is expected to have definitely more than 25 entries in the test database)
        before { get(api_v3_meeting_relay_swimmers_path, params: { stroke_type_id: 1 }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific relay_order,' do
        before { get(api_v3_meeting_relay_swimmers_path, params: { relay_order: 1 }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meeting_relay_swimmers_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_meeting_relay_swimmers_path, params: { swimmer_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
