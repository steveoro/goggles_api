# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'

RSpec.describe Goggles::UsersAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:fixture_user) { FactoryBot.create(:user) }
  let(:api_user)     { FactoryBot.create(:user) }
  let(:jwt_token)    { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce context domain creation
  before(:each) do
    expect(fixture_user).to be_a(GogglesDb::User).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  context 'GET /api/v3/user/:id' do
    it 'returns the selected user as JSON' do
      get api_v3_user_path(id: fixture_user.id), headers: fixture_headers
      expect(response.status).to eq(200)
      expect(response.body).to eq(fixture_user.to_json)
    end
  end
end
