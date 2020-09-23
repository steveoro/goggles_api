# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Users API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200923
  #
  class BadgesAPI < Grape::API
    format        :json
    content_type  :json, 'application/json'

    resource :badge do
      # GET /api/:version/badge/:id
      #
      # == Returns:
      # The Badge instance matching the specified +id+ as JSON.
      #
      desc 'Badge details'
      params do
        requires :id, type: Integer, desc: 'Badge ID'
      end
      route_param :id do
        get do
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          GogglesDb::Badge.find_by_id(params['id'])
        end
      end
    end
  end
end
