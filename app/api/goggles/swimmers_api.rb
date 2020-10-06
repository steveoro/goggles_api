# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Swimmer API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class SwimmersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :swimmer do
      # GET /api/:version/swimmer/:id
      #
      # == Returns:
      # The Swimmer instance matching the specified +id+ as JSON.
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
