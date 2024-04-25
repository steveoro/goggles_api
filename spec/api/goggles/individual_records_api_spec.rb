# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::IndividualRecordsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'IndividualRecord') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:individual_record) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::IndividualRecord).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/individual_record/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_individual_record_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_individual_record_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_individual_record_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_individual_record_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end

  describe 'PUT /api/v3/individual_record/:id' do
    let(:new_ir) { FactoryBot.create(:individual_record) }
    let(:expected_changes) do
      [
        { event_type_id: new_ir.event_type_id, team_id: new_ir.team_id, swimmer_id: new_ir.swimmer_id },
        { season_id: new_ir.season_id, swimmer_id: new_ir.swimmer_id, team_record: [true, false].sample },
        { record_type_id: new_ir.record_type_id, minutes: 0, seconds: ((rand * 59) % 59).to_i, hundredths: ((rand * 59) % 59).to_i },
        { federation_type_id: new_ir.federation_type_id, meeting_individual_result_id: new_ir.meeting_individual_result_id },
        { pool_type_id: new_ir.pool_type_id, category_type_id: new_ir.category_type_id, gender_type_id: new_ir.gender_type_id }
      ].sample
    end

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_ir).to be_a(GogglesDb::IndividualRecord).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_individual_record_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_individual_record_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_individual_record_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_individual_record_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_individual_record_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/individual_record' do
    let(:built_row) { FactoryBot.build(:individual_record) }

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::IndividualRecord).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { post(api_v3_individual_record_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_individual_record_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_individual_record_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_individual_record_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    # NOTE: for legacy reasons IR were supposed to be created even with a lot of invalid parameters
    #       (negative or null IDs), so for the moment we'll just check the "missing" outcome.
    context 'when calling with missing parameters,' do
      before do
        post(
          api_v3_individual_record_path,
          params: {
            pool_type_id: built_row.pool_type_id,
            event_type_id: built_row.event_type_id,
            category_type_id: built_row.category_type_id,
            gender_type_id: built_row.gender_type_id,
            team_id: built_row.team_id,
            swimmer_id: built_row.swimmer_id,
            record_type_id: built_row.record_type_id
          },
          headers: crud_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a specific error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq('season_id is missing, federation_type_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/individual_record/:id' do
    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:individual_record) }

      before { expect(deletable_row).to be_a(GogglesDb::IndividualRecord).and be_valid }

      context 'with an account having CRUD grants,' do
        before { delete(api_v3_individual_record_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_individual_record_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { delete(api_v3_individual_record_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_individual_record_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_individual_record_path(id: -1), headers: crud_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/individual_records/' do
    context 'when using a valid authentication' do
      let(:swimmer_id_with_multipage_ir) do
        GogglesDb::IndividualRecord.group(:swimmer_id).count
                                   .reject { |_k, count| count < 26 }.first(20)
                                   .map(&:first).sample
      end
      let(:default_per_page) { 25 }
      let(:expected_row_count) { GogglesDb::IndividualRecord.where(swimmer_id: swimmer_id_with_multipage_ir).count }
      # Make sure the Domain contains the expected seeds:

      before do
        expect(swimmer_id_with_multipage_ir).to be_positive
        expect(expected_row_count).to be_positive
      end

      context 'without any filters,' do
        before { get(api_v3_individual_records_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_individual_records_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific meeting_program_id,' do
        before { get(api_v3_individual_records_path, params: { swimmer_id: swimmer_id_with_multipage_ir }, headers: fixture_headers) }

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific team_id,' do
        # (Team ID 1 is expected to have more than 600 IR entries in the test database)
        before { get(api_v3_individual_records_path, params: { team_id: 1 }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_individual_records_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_individual_records_path, params: { swimmer_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
