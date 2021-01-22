# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::LapsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:lap) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::Lap).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/lap/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_lap_path(id: fixture_row.id), headers: fixture_headers) }
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_row.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_lap_path(id: -1), headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Lap') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  describe 'PUT /api/v3/lap/:id' do
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end
    context 'when using valid parameters,' do
      let(:new_lap) { FactoryBot.build(:lap) }
      let(:expected_changes) do
        [
          { meeting_program_id: new_lap.meeting_program_id, meeting_individual_result_id: nil, meeting_entry_id: nil },
          { team_id: new_lap.team_id, swimmer_id: new_lap.swimmer_id },
          { minutes: 0, seconds: ((rand * 59) % 59).to_i, hundreds: ((rand * 100) % 100).to_i },
          { minutes_from_start: ((rand * 4) % 4).to_i, seconds_from_start: ((rand * 59) % 59).to_i, hundreds_from_start: ((rand * 100) % 100).to_i },
          { position: (rand * 10).to_i, reaction_time: (rand + 0.07).round(2) }
        ].sample
      end
      before(:each) do
        expect(new_lap).to be_a(GogglesDb::Lap).and be_valid
        expect(expected_changes).to be_an(Hash).and be_present
      end

      context 'with an account having CRUD grants,' do
        before(:each) do
          put(api_v3_lap_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
        end
        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns true' do
          expect(response.body).to eq('true')
          updated_row = fixture_row.reload
          expected_changes.each do |key, value|
            expect(updated_row.send(key)).to eq(value)
          end
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) do
          put(api_v3_lap_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_lap_path(id: fixture_row.id),
          params: { no_time: true },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_lap_path(id: -1),
          params: { no_time: true },
          headers: crud_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/lap' do
    let(:built_row) { FactoryBot.build(:lap) }
    before(:each) { expect(built_row).to be_a(GogglesDb::Lap).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before(:each) do
          expect(crud_user).to be_a(GogglesDb::User).and be_valid
          expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
          expect(crud_headers).to be_an(Hash).and have_key('Authorization')
          post(api_v3_lap_path, params: built_row.attributes, headers: crud_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns the result msg and the new row as JSON' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg').and have_key('new')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
          attr_extractor = ->(hash) { hash.reject { |key, _value| %w[id lock_version created_at updated_at].include?(key.to_s) } }
          resulting_hash = attr_extractor.call(result['new'])
          expected_hash  = attr_extractor.call(built_row.attributes)
          # Adapt expected hash to the JSON-ified result which will store floats as strings so that the comparison is simpler:
          expected_hash.each { |key, val| expected_hash[key] = val.to_s if val.is_a?(BigDecimal) || val.is_a?(Float) }
          expect(resulting_hash).to eq(expected_hash)
        end
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_lap_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_lap_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using missing parameters,' do
      before(:each) do
        expect(crud_user).to be_a(GogglesDb::User).and be_valid
        expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
        expect(crud_headers).to be_an(Hash).and have_key('Authorization')
        post(
          api_v3_lap_path,
          params: {
            meeting_program_id: built_row.meeting_program_id,
            team_id: built_row.team_id
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
        expect(result['error']).to eq('swimmer_id is missing')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/lap/:id' do
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end
    context 'when using valid parameters,' do
      let(:deletable_row) { FactoryBot.create(:lap) }
      before(:each) { expect(deletable_row).to be_a(GogglesDb::Lap).and be_valid }

      context 'with an account having CRUD grants,' do
        before(:each) { delete(api_v3_lap_path(id: deletable_row.id), headers: crud_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'deletes the row and returns true' do
          expect(response.body).to eq('true')
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) do
          delete(api_v3_lap_path(id: fixture_row.id), headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        delete(api_v3_lap_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        delete(api_v3_lap_path(id: -1), headers: crud_headers)
      end
      it_behaves_like 'a successful response with an empty body'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/laps/' do
    context 'when using a valid authentication' do
      let(:fixture_mprg_id) { GogglesDb::Lap.last(200).sample.meeting_program_id }
      let(:fixture_mir) { GogglesDb::Lap.includes(:meeting_individual_result).joins(:meeting_individual_result).last(200).sample.meeting_individual_result }
      let(:default_per_page) { 25 }
      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_mprg_id).to be_positive
        expect(fixture_mir).to be_a(GogglesDb::MeetingIndividualResult).and be_valid
      end

      context 'without any filters,' do
        before(:each) { get(api_v3_laps_path, headers: fixture_headers) }
        it 'is successful' do
          expect(response).to be_successful
        end
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      context 'when filtering by a specific meeting_program_id,' do
        let(:expected_row_count) { GogglesDb::Lap.where(meeting_program_id: fixture_mprg_id).count }
        before(:each) do
          expect(expected_row_count).to be_positive
          get(api_v3_laps_path, params: { meeting_program_id: fixture_mprg_id }, headers: fixture_headers)
        end
        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by a specific meeting_individual_result_id,' do
        let(:expected_row_count) { GogglesDb::Lap.where(meeting_individual_result_id: fixture_mir.id).count }
        before(:each) do
          expect(expected_row_count).to be_positive
          get(api_v3_laps_path, params: { meeting_individual_result_id: fixture_mir.id }, headers: fixture_headers)
        end
        # This will support even just 1 result row:
        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by a specific swimmer_id,' do
        let(:expected_row_count) { GogglesDb::Lap.where(swimmer_id: fixture_mir.swimmer_id).count }
        before(:each) do
          expect(expected_row_count).to be_positive
          get(api_v3_laps_path, params: { swimmer_id: fixture_mir.swimmer_id }, headers: fixture_headers)
        end
        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by a specific team_id,' do
        # (Team ID 1 is expected to have definitely more than 25 entries in the test database)
        before(:each) { get(api_v3_laps_path, params: { team_id: 1 }, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_laps_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_laps_path, params: { team_id: -1 }, headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
