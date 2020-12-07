# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_team) { FactoryBot.create(:team, city: FactoryBot.create(:city)) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_team).to be_a(GogglesDb::Team).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/team/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_team_path(id: fixture_team.id), headers: fixture_headers) }

      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_team.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_team_path(id: fixture_team.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get api_v3_team_path(id: -1), headers: fixture_headers }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/team/:id' do
    let(:new_team_values) { FactoryBot.build(:team) }
    let(:crud_user) { FactoryBot.create(:user) }
    let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Team') }
    let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:expected_changes) do
        [
          { name: new_team_values.name, editable_name: new_team_values.editable_name },
          { city_id: new_team_values.city_id, address: new_team_values.address, zip: new_team_values.zip },
          { phone_mobile: new_team_values.phone_mobile, phone_number: new_team_values.phone_number },
          { e_mail: new_team_values.e_mail, contact_name: new_team_values.contact_name },
          { notes: new_team_values.notes },
          { home_page_url: new_team_values.home_page_url }
        ].sample
      end
      before(:each) { expect(expected_changes).to be_an(Hash) }

      context 'with an account having CRUD grants,' do
        before(:each) do
          put(api_v3_team_path(id: fixture_team.id), params: expected_changes, headers: crud_headers)
        end
        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns true' do
          expect(response.body).to eq('true')
          updated_row = fixture_team.reload
          expected_changes.each do |key, _value|
            expect(updated_row.send(key)).to eq(expected_changes[key])
          end
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) do
          put(api_v3_team_path(id: fixture_team.id), params: expected_changes, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_team_path(id: fixture_team.id),
          params: { name: new_team_values.name },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_team_path(id: -1),
          params: { name: new_team_values.name },
          headers: crud_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/teams/' do
    context 'when using a valid authentication' do
      let(:fixture_city_id) { [2, 3, 4, 5, 37].sample }
      let(:default_per_page)  { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) { expect(GogglesDb::Team.where(city_id: fixture_city_id).count).to be_positive }

      context 'without any filters,' do
        before(:each) { get(api_v3_teams_path, headers: fixture_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific city_id,' do
        before(:each) { get(api_v3_teams_path, params: { city_id: fixture_city_id }, headers: fixture_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::Team.where(city_id: fixture_city_id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        # (We can't really assert pagination links here, it's enough to test these in the context below)
      end

      %w[name editable_name].each do |field_name|
        context "filtering by a partial #{field_name}," do
          let(:fixture_name) { GogglesDb::Team.select(field_name).limit(50).map(&field_name.to_sym).sample }
          let(:expected_team) { GogglesDb::Team.where("#{field_name} LIKE ?", "%#{fixture_name}%").first }
          let(:expected_row_count) { GogglesDb::Team.where("#{field_name} LIKE ?", "%#{fixture_name}%").count }

          before(:each) { get(api_v3_teams_path, params: { field_name => fixture_name }, headers: fixture_headers) }

          it 'is successful' do
            expect(response).to be_successful
          end
          it 'returns a JSON array containing the single expected row' do
            result_array = JSON.parse(response.body)
            expect(result_array).to be_an(Array)
            expect(result_array.count).to be >= 1
            expect(result_array.first['id']).to eq(expected_team.id)
          end

          # Typically any results filtered by name will be just a single row fitting
          # in a single page (w/o pagination links), but with random names we can't be sure:
          it_behaves_like 'multiple row response either with OR without pagination links'
        end
      end

      # Uses random fixtures, to have a quick 1-row result (no pagination, always):
      context 'filtering by a specific single random fixture,' do
        before(:each) { get(api_v3_teams_path, params: { city_id: fixture_team.city_id }, headers: fixture_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_team].to_json)
        end
        it_behaves_like 'single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_teams_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_teams_path, params: { city_id: -1 }, headers: fixture_headers) }

      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
