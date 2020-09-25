# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Users API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200925
  #
  class TeamsAPI < Grape::API
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
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          GogglesDb::Team.find_by_id(params['id'])
        end
      end
    end
  end
end
