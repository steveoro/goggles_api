# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Users API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200925
  #
  class SwimmersAPI < Grape::API
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
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          GogglesDb::Swimmer.find_by_id(params['id'])
        end
      end
    end
  end
end
