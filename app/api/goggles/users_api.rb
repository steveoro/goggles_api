# frozen_string_literal: true

module Goggles
  # = Goggles API v3: User API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class UsersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :user do
      # GET /api/:version/user/:id
      #
      # == Returns:
      # The User instance matching the specified +id+ as JSON.
      #
      desc 'User details'
      params do
        requires :id, type: Integer, desc: 'User ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::User.find_by_id(params['id'])
        end
      end
    end
  end
end
