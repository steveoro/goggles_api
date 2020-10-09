# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::BadgesAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_badge) { FactoryBot.create(:badge) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_badge).to be_a(GogglesDb::Badge).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/badge/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_badge_path(id: fixture_badge.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected row as JSON' do
        expect(response.body).to eq(fixture_badge.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_badge_path(id: fixture_badge.id), headers: { 'Authorization' => 'you wish!' }
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_badge_path(id: -1), headers: fixture_headers
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/badge/:id' do
    context 'when using valid parameters,' do
      let(:expected_changes) do
        [
          { number: 'TEST_CODE' },
          { number: 'TEST_CODE', entry_time_type_id: GogglesDb::EntryTimeType.send(%w[manual personal gogglecup prec_year last_race].sample).id },
          { number: 'TEST_CODE', has_to_pay_fees: true },
          { number: 'TEST_CODE', has_to_pay_relays: true, has_to_pay_badge: [false, true].sample }
        ].sample
      end
      before(:each) do
        put(
          api_v3_badge_path(id: fixture_badge.id),
          params: expected_changes,
          headers: fixture_headers
        )
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'updates the row and returns true' do
        expect(response.body).to eq('true')
        updated_row = fixture_badge.reload
        expected_changes.each do |key, _value|
          expect(updated_row.send(key)).to eq(expected_changes[key])
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_badge_path(id: fixture_badge.id),
          params: { number: 'TEST_CODE' },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_badge_path(id: -1),
          params: { number: 'TEST_CODE' },
          headers: fixture_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/badges/' do
    context 'when using a valid authentication' do
      let(:fixture_team)      { GogglesDb::Team.first }
      let(:fixture_season_id) { [171, 172, 181, 182, 191, 192].sample }
      let(:default_per_page)  { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_team).to be_a(GogglesDb::Team).and be_valid
        expect(fixture_team.badges.count).to be > 1400
        # Team ID 1 => actual Badges x Seasons: 171=80, 172=32, 181=75, 182=37, 191=75, 192=35
        expect(fixture_team.badges.where(season_id: fixture_season_id).count).to be > 30
      end

      context 'without any filters,' do
        before(:each) do
          get(api_v3_badges_path, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific team_id & season_id,' do
        before(:each) do
          get(api_v3_badges_path, params: { team_id: fixture_team.id, season_id: fixture_season_id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific swimmer_id,' do
        # Note: some actual swimmers from the selected seasons may have just a handful of badges,
        #       so pagination is not guarateed to be there and we don't need to test that here.
        let(:fixture_swimmer) { fixture_team.badges.where(season_id: fixture_season_id).sample.swimmer }
        before(:each) do
          expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
          get(api_v3_badges_path, params: { swimmer_id: fixture_swimmer.id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns an array of JSON rows (when the result list has more than per_page rows)' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::Badge.where(swimmer_id: fixture_swimmer.id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
      end

      # Uses random fixtures, to have a quick 1-row result (no pagination, always):
      context 'filtering by a specific team_affiliation_id for a random single fixture,' do
        before(:each) do
          get(api_v3_badges_path, params: { team_affiliation_id: fixture_badge.team_affiliation_id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_badge].to_json)
        end
        it_behaves_like 'single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get(api_v3_badges_path, headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) do
        get(api_v3_badges_path, params: { team_id: -1 }, headers: fixture_headers)
      end
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
