# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'

RSpec.describe Goggles::SwimmersAPI, tag: :performance, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  describe 'GET /api/v3/swimmers/', :n_plus_one do
    # The `populate` callbacks is responsible for data generation/population.
    # (Accepts scale factor as parameter)
    # populate { |_n| nil } # (no-op: pre-seeded database)

    specify do
      api_user  = GogglesDb::User.first
      jwt_token = jwt_for_api_session(api_user)
      fixture_headers = { 'Authorization' => "Bearer #{jwt_token}" }
      expect { get(api_v3_swimmers_path, headers: fixture_headers) }.to perform_constant_number_of_queries
    end
  end

  describe 'GET /api/v3/swimmer/:id', :n_plus_one do
    specify do
      api_user  = GogglesDb::User.first
      jwt_token = jwt_for_api_session(api_user)
      fixture_headers = { 'Authorization' => "Bearer #{jwt_token}" }
      expect { get(api_v3_swimmer_path(id: 142), headers: fixture_headers) }.to perform_constant_number_of_queries
    end
  end
end
