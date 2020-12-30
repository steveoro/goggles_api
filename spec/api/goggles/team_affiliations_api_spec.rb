# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamAffiliationsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)   { FactoryBot.create(:user) }
  let(:jwt_token)  { jwt_for_api_session(api_user) }
  let(:fixture_ta) { FactoryBot.create(:affiliation_with_badges) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_ta).to be_a(GogglesDb::TeamAffiliation).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/team_affiliation/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_team_affiliation_path(id: fixture_ta.id), headers: fixture_headers) }
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_ta.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_team_affiliation_path(id: fixture_ta.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_team_affiliation_path(id: -1), headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'TeamAffiliation') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  describe 'PUT /api/v3/team_affiliation/:id' do
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end
    context 'when using valid parameters,' do
      let(:new_team)   { FactoryBot.create(:team) }
      let(:new_season) { FactoryBot.create(:season) }
      let(:new_name)   { new_team.editable_name.downcase.titleize }
      let(:new_number) { format('%<number>08d', number: (rand * 100_000).to_i) }
      let(:expected_changes) do
        [
          { team_id: new_team.id },
          { season_id: new_season.id },
          { name: new_name },
          { number: new_number },
          { compute_gogglecup: [true, false].sample }
        ].sample
      end
      before(:each) do
        expect(new_team).to be_a(GogglesDb::Team).and be_valid
        expect(new_season).to be_a(GogglesDb::Season).and be_valid
        expect(new_name).to be_present
        expect(new_number).to be_present
      end

      context 'with an account having CRUD grants,' do
        before(:each) do
          put(api_v3_team_affiliation_path(id: fixture_ta.id), params: expected_changes, headers: crud_headers)
        end
        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns true' do
          expect(response.body).to eq('true')
          updated_row = fixture_ta.reload
          expected_changes.each do |key, value|
            expect(updated_row.send(key)).to eq(value)
          end
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) do
          put(api_v3_team_affiliation_path(id: fixture_ta.id), params: expected_changes, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_team_affiliation_path(id: fixture_ta.id),
          params: { compute_gogglecup: true },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_team_affiliation_path(id: -1),
          params: { compute_gogglecup: true },
          headers: crud_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/team_affiliation' do
    let(:new_team)   { FactoryBot.create(:team) }
    let(:new_season) { FactoryBot.create(:season) }
    let(:built_row)  { FactoryBot.build(:team_affiliation, team: new_team, season: new_season) }
    let(:admin_user) { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
    before(:each) do
      expect(new_team).to be_a(GogglesDb::Team).and be_valid
      expect(new_season).to be_a(GogglesDb::Season).and be_valid
      expect(built_row).to be_a(GogglesDb::TeamAffiliation).and be_valid
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_team_affiliation_path, params: built_row.attributes, headers: admin_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns the result msg and the new row as JSON' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg').and have_key('new')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
          attr_extractor = ->(hash) { hash.reject { |key, _value| %w[id lock_version created_at updated_at].include?(key.to_s) } }
          expect(attr_extractor.call(result['new'])).to eq(attr_extractor.call(built_row.attributes))
        end
      end

      context 'with an account having just CRUD grants,' do
        before(:each) do
          expect(crud_user).to be_a(GogglesDb::User).and be_valid
          expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
          expect(crud_headers).to be_an(Hash).and have_key('Authorization')
          post(api_v3_team_affiliation_path, params: built_row.attributes, headers: crud_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_team_affiliation_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_team_affiliation_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using missing or invalid parameters,' do
      before(:each) { post(api_v3_team_affiliation_path, params: { team_id: built_row.team_id, season_id: -1 }, headers: admin_headers) }

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

  describe 'GET /api/v3/team_affiliations/' do
    context 'when using a valid authentication' do
      let(:fixture_season_id) { [171, 172, 181, 182, 191, 192].sample }
      let(:fixture_team)      { GogglesDb::Team.first }
      let(:default_per_page)  { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_season_id).to be_positive
        expect(fixture_team).to be_a(GogglesDb::Team).and be_valid
        expect(GogglesDb::TeamAffiliation.where(season_id: fixture_season_id).count).to be_positive
        expect(GogglesDb::TeamAffiliation.where(team_id: fixture_team.id).count).to be_positive
      end

      context 'without any filters,' do
        before(:each) { get(api_v3_team_affiliations_path, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      context 'when filtering by a specific season_id,' do
        before(:each) { get(api_v3_team_affiliations_path, params: { season_id: fixture_season_id }, headers: fixture_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::TeamAffiliation.where(season_id: fixture_season_id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        # (We can't really assert pagination links here, it's enough to test these in the context below)
      end

      context 'when filtering by a specific team_id,' do
        before(:each) { get(api_v3_team_affiliations_path, params: { team_id: fixture_team.id }, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      context 'when filtering by a partial name,' do
        let(:fixture_name) { 'Ferrari' } # (This will surely have more than 'default_per_page' results)
        let(:expected_results) { GogglesDb::TeamAffiliation.where('name LIKE ?', "%#{fixture_name}%") }
        before(:each) { get(api_v3_team_affiliations_path, params: { name: fixture_name }, headers: fixture_headers) }

        it 'returns a paginated JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = expected_results.count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
          expected_team_id = expected_results.first.team_id
          expect(result_array.map { |arr| arr['team_id'] }).to all eq(expected_team_id)
        end
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      # Uses random fixtures, to have a quick 1-row result (no pagination, always):
      context 'when filtering by a specific single random fixture,' do
        before(:each) do
          get(
            api_v3_team_affiliations_path,
            params: {
              season_id: fixture_ta.season_id,
              team_id: fixture_ta.team_id,
              compute_gogglecup: fixture_ta.compute_gogglecup
            },
            headers: fixture_headers
          )
        end

        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_ta].to_json)
        end
        it_behaves_like 'successful single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_team_affiliations_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_team_affiliations_path, params: { season_id: -1 }, headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
