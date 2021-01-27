# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::BadgesAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:badge) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Badge') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::Badge).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/badge/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_badge_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_badge_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_badge_path(id: -1), headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/badge/:id' do
    let(:expected_changes) do
      [
        { number: 'TEST_CODE' },
        { number: 'TEST_CODE', entry_time_type_id: GogglesDb::EntryTimeType.send(%w[manual personal gogglecup prec_year last_race].sample).id },
        { number: 'TEST_CODE', fees_due: true },
        { number: 'TEST_CODE', relays_due: true, badge_due: [false, true].sample }
      ].sample
    end
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before(:each) { put(api_v3_badge_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account not having the proper grants,' do
        before(:each) { put(api_v3_badge_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_badge_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { put(api_v3_badge_path(id: -1), params: expected_changes, headers: crud_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/badge' do
    let(:new_swimmer) { FactoryBot.create(:swimmer) }
    let(:new_category_type) { FactoryBot.create(:category_type) }
    let(:new_team_affiliation) { FactoryBot.create(:team_affiliation, season: new_category_type.season) }
    let(:built_row) do
      FactoryBot.build(
        :badge,
        swimmer: new_swimmer,
        team_affiliation: new_team_affiliation,
        category_type: new_category_type,
        season: new_category_type.season,
        team: new_team_affiliation.team
      )
    end
    let(:admin_user)  { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
      expect(new_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
      expect(new_category_type).to be_a(GogglesDb::CategoryType).and be_valid
      expect(new_team_affiliation).to be_a(GogglesDb::TeamAffiliation).and be_valid
      expect(built_row).to be_a(GogglesDb::Badge).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_badge_path, params: built_row.attributes, headers: admin_headers) }
        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before(:each) { post(api_v3_badge_path, params: built_row.attributes, headers: crud_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_badge_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_badge_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using invalid parameters,' do
      before(:each) do
        post(
          api_v3_badge_path,
          params: built_row.attributes.merge(team_id: -1),
          headers: admin_headers
        )
      end

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
        before(:each) { get(api_v3_badges_path, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific team_id & season_id,' do
        before(:each) { get(api_v3_badges_path, params: { team_id: fixture_team.id, season_id: fixture_season_id }, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      context 'when filtering by a specific swimmer_id,' do
        let(:fixture_swimmer) { fixture_team.badges.where(season_id: fixture_season_id).sample.swimmer }
        let(:expected_row_count) { GogglesDb::Badge.where(swimmer_id: fixture_swimmer.id).count }
        before(:each) do
          expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
          expect(expected_row_count).to be_positive
          get(api_v3_badges_path, params: { swimmer_id: fixture_swimmer.id }, headers: fixture_headers)
        end
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      # Uses random fixtures to have a quick 1-row result (no pagination, always):
      context 'when filtering by a specific team_affiliation_id for a random single fixture,' do
        before(:each) { get(api_v3_badges_path, params: { team_affiliation_id: fixture_row.team_affiliation_id }, headers: fixture_headers) }
        it_behaves_like('successful single response without pagination links in headers')

        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_row].to_json)
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_badges_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_badges_path, params: { team_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
