# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::GoggleCupManageAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:season_year) { 2024 }
  let(:managed_season) do
    FactoryBot.create(:season, season_type_id: GogglesDb::SeasonType::MAS_FIN_ID,
                               begin_date: Date.new(season_year, 9, 1),
                               end_date: Date.new(season_year + 1, 6, 30))
  end
  let(:team) { FactoryBot.create(:team) }
  let(:team_affiliation) { FactoryBot.create(:team_affiliation, team: team, season: managed_season) }
  let(:fixture_row) do
    FactoryBot.create(:goggle_cup, team: team, season_year: season_year, swimmers_ids: '1,2,3')
  end

  # Admin:
  let(:admin_user)    { FactoryBot.create(:user) }
  let(:admin_grant)   { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # Team manager for (team, season_year):
  let(:manager_user)    { FactoryBot.create(:user) }
  let(:managed_aff)     { FactoryBot.create(:managed_affiliation, manager: manager_user, team_affiliation: team_affiliation) }
  let(:manager_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(manager_user)}" } }
  # Manager of the same team but for a DIFFERENT championship year:
  let(:past_manager_user) { FactoryBot.create(:user) }
  let(:past_managed_aff) do
    FactoryBot.create(
      :managed_affiliation, manager: past_manager_user,
                            team_affiliation: FactoryBot.create(
                              :team_affiliation, team: team,
                                                 season: FactoryBot.create(
                                                   :season,
                                                   season_type_id: GogglesDb::SeasonType::MAS_FIN_ID,
                                                   begin_date: Date.new(season_year - 5, 9, 1),
                                                   end_date: Date.new(season_year - 4, 6, 30)
                                                 )
                            )
    )
  end
  let(:past_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(past_manager_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user) { FactoryBot.create(:user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(api_user)}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::GoggleCup).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(managed_aff).to be_a(GogglesDb::ManagedAffiliation).and be_valid
    expect(past_managed_aff).to be_a(GogglesDb::ManagedAffiliation).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
  end

  describe 'GET /api/v3/goggle_cup_manage/swimmer_options' do
    let(:path) { api_v3_goggle_cup_manage_swimmer_options_path }

    it 'rejects unauthenticated requests' do
      get(path, params: { team_id: team.id, season_year: season_year })
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects users with no grants' do
      get(path, params: { team_id: team.id, season_year: season_year }, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects managers of the team for a different championship year' do
      get(path, params: { team_id: team.id, season_year: season_year }, headers: past_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows team managers of the requested affiliation' do
      get(path, params: { team_id: team.id, season_year: season_year }, headers: manager_headers)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it 'allows admins' do
      get(path, params: { team_id: team.id, season_year: season_year }, headers: admin_headers)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v3/goggle_cup_manage/smart_selection' do
    let(:path) { api_v3_goggle_cup_manage_smart_selection_path }

    it 'rejects unauthorized users' do
      get(path, params: { team_id: team.id, season_year: season_year }, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns a swimmer_ids array' do
      get(path, params: { team_id: team.id, season_year: season_year, secondary_team_id: team.id },
                headers: manager_headers)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to have_key('swimmer_ids')
    end
  end

  describe 'GET /api/v3/goggle_cup_manage/:id/sync' do
    it 'rejects unauthorized users' do
      get(api_v3_goggle_cup_manage_sync_path(id: fixture_row.id), headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the sync payload (cup + affiliation + badges)' do
      get(api_v3_goggle_cup_manage_sync_path(id: fixture_row.id), headers: manager_headers)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['cup']['id']).to eq(fixture_row.id)
      expect(json['sync']['goggle_cup']['id']).to eq(fixture_row.id)
      expect(json['sync']).to have_key('team_affiliation').and have_key('badges')
    end
  end

  describe 'POST /api/v3/goggle_cup_manage' do
    let(:path) { api_v3_goggle_cup_manage_path }
    let(:create_params) do
      { team_id: team.id, season_year: season_year, description: 'New managed cup',
        swimmer_ids: [1, 2, 3] }
    end

    it 'rejects unauthorized users' do
      post(path, params: create_params, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the cup and returns cup + badges_report + sync' do
      expect do
        post(path, params: create_params, headers: manager_headers)
        expect(response).to have_http_status(:created)
      end.to change(GogglesDb::GoggleCup, :count).by(1)
      json = JSON.parse(response.body)
      expect(json['cup']['description']).to eq('New managed cup')
      expect(json['cup']['name']).to eq('New managed cup')
      expect(json['cup']['swimmers_ids']).to eq('1,2,3')
      expect(json).to have_key('badges_report').and have_key('sync')
    end

    it 'honors an explicit name distinct from description' do
      post(path, params: create_params.merge(name: 'GoggleCup'), headers: manager_headers)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['cup']['name']).to eq('GoggleCup')
    end

    it 'fails with 422 on invalid params' do
      post(path, params: create_params.merge(description: ''), headers: manager_headers)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PUT /api/v3/goggle_cup_manage/:id' do
    let(:path) { api_v3_goggle_cup_manage_path(id: fixture_row.id) }

    it 'rejects unauthorized users' do
      put(path, params: { description: 'x' }, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'updates config without clearing a stored ranking when selection is unchanged' do
      fixture_row.update!(ranking_data: '{"no_duplicated_events":false,"data":{"scores":{},"base_timings":{}}}')
      put(path, params: { name: 'Renamed' }, headers: manager_headers)
      expect(response).to have_http_status(:ok)
      fixture_row.reload
      expect(fixture_row.name).to eq('Renamed')
      expect(fixture_row.ranking_data).to be_present
    end

    it 'clears the stored ranking when the swimmer selection changes' do
      fixture_row.update!(ranking_data: '{"no_duplicated_events":false,"data":{"scores":{},"base_timings":{}}}')
      put(path, params: { swimmer_ids: [5, 6] }, headers: manager_headers)
      expect(response).to have_http_status(:ok)
      fixture_row.reload
      expect(fixture_row.swimmers_ids).to eq('5,6')
      expect(fixture_row.ranking_data).to be_nil
    end

    it 'ignores a blank name instead of emptying it' do
      put(path, params: { name: '' }, headers: manager_headers)
      expect(response).to have_http_status(:ok)
      expect(fixture_row.reload.name).to eq(fixture_row.name)
    end

    it 'rejects managers of the team for a different championship year' do
      put(path, params: { name: 'Renamed' }, headers: past_headers)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v3/goggle_cup_manage/:id/compute' do
    let(:path) { api_v3_goggle_cup_manage_compute_path(id: fixture_row.id) }

    it 'rejects unauthorized users' do
      post(path, params: {}, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'persists the computed ranking inside ranking_data' do
      fake_ranking = [{ swimmer_id: 1, swimmer_name: 'TEST SWIMMER', overall_score: 1000.0,
                        top_rows: [], base_rows: [] }]
      calculator = instance_double(GogglesDb::GogglesCup::RankingCalculator, call: fake_ranking)
      allow(GogglesDb::GogglesCup::RankingCalculator).to receive(:new).and_return(calculator)

      post(path, params: { swimmer_ids: [1, 2, 3], no_duplicated_events: true }, headers: manager_headers)
      expect(response).to have_http_status(:created)
      fixture_row.reload
      expect(fixture_row.ranking_data).to be_present
      expect(JSON.parse(fixture_row.ranking_data)['no_duplicated_events']).to be(true)
      expect(JSON.parse(fixture_row.ranking_data)['swimmer_ids']).to eq([1, 2, 3])
      expect(JSON.parse(response.body)['ranking']).not_to be_empty
    end

    it 'returns 422 when no swimmers resolve' do
      post(path, params: { swimmer_ids: [] }, headers: manager_headers)
      expect(response).to have_http_status(:unprocessable_content)
      expect(fixture_row.reload.ranking_data).to be_nil
    end
  end

  describe 'POST /api/v3/goggle_cup_manage/:id/clear_ranking' do
    let(:path) { api_v3_goggle_cup_manage_clear_ranking_path(id: fixture_row.id) }

    it 'rejects unauthorized users' do
      post(path, headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'clears ranking_data' do
      fixture_row.update!(ranking_data: '{"a":1}')
      post(path, headers: manager_headers)
      expect(response).to have_http_status(:created)
      expect(fixture_row.reload.ranking_data).to be_nil
    end
  end

  describe 'POST /api/v3/goggle_cup_manage/:id/publish & /unpublish' do
    let(:sibling_cup) { FactoryBot.create(:goggle_cup, team: team, season_year: season_year) }
    let(:other_affiliation_cup) do
      FactoryBot.create(:goggle_cup, season_year: season_year, published: true)
    end

    it 'rejects unauthorized users' do
      post(api_v3_goggle_cup_manage_publish_path(id: fixture_row.id), headers: fixture_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'publishes the cup and resets siblings of the same affiliation' do
      sibling_cup.update!(published: true)
      post(api_v3_goggle_cup_manage_publish_path(id: fixture_row.id), headers: manager_headers)
      expect(response).to have_http_status(:created)
      expect(fixture_row.reload.published).to be(true)
      expect(sibling_cup.reload.published).to be(false)
      expect(other_affiliation_cup.reload.published).to be(true)
    end

    it 'unpublishes the cup' do
      fixture_row.update!(published: true)
      post(api_v3_goggle_cup_manage_unpublish_path(id: fixture_row.id), headers: manager_headers)
      expect(response).to have_http_status(:created)
      expect(fixture_row.reload.published).to be(false)
    end
  end
end
