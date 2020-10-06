# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Team API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class TeamsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :team do
      # GET /api/:version/team/:id
      #
      # == Returns:
      # The Team instance matching the specified +id+ as JSON.
      # See GogglesDb::Team#to_json for structure details.
      #
      desc 'Team details'
      params do
        requires :id, type: Integer, desc: 'Team ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Team.find_by_id(params['id'])
        end
      end
    end
  end
end
