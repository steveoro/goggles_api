# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_team) { FactoryBot.create(:team) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_team).to be_a(GogglesDb::Team).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/team/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_team_path(id: fixture_team.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_team.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_team_path(id: fixture_team.id), headers: { 'Authorization' => 'you wish!' }
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_team_path(id: -1), headers: fixture_headers
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
end
