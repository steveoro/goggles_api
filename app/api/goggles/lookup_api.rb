# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Swimmer API Grape controller
  #
  #   - version:  1.09
  #   - author:   Steve A.
  #   - build:    20201207
  #
  class SwimmersAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :lookup do
      # GET /api/:version/lookup/:entity_name (plural)
      #
      # == Returns:
      # The JSON list of possible lookup values associated to the specified lookup entity,
      # matching the filters provided.
      # See GogglesDb::Swimmer#to_json for structure details.
      #
      desc 'Swimmer details'
      params do
        requires :id, type: Integer, desc: 'Swimmer ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Swimmer.find_by_id(params['id'])
        end
      end
    end
  end
end
