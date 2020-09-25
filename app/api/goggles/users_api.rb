# frozen_string_literal: true

module Goggles
  # = Goggles API v3: User API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200911
  #
  class UsersAPI < Grape::API
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
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          GogglesDb::User.find_by_id(params['id'])
        end
      end
    end
  end
end
