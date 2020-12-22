# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Session API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200923
  #
  # Please, note that this is the only *singular* named API implementation file, due
  # to this endpoint handling 1 session at a time.
  #
  # Associated spec file mirrors this naming convention.
  #
  class SessionAPI < Grape::API
    format        :json
    content_type  :json, 'application/json'

    resource :session do
      # POST /api/:version/session
      #
      # Creates a new JWT for an API session if the given credentials are valid.
      #
      # == Params:
      # - e: User email
      # - p: User password
      # - t: static authorization token for this API
      #
      # == Returns:
      # A new JWT.
      #
      desc 'Create a new JWT session'
      params do
        requires :e, type: String, desc: 'User email'
        requires :p, type: String, desc: 'User password'
        requires :t, type: String, desc: 'Static Authorization token for this API'
      end
      post do
        # Without the correct static token, the authentication won't even begin:
        params['t'] != Rails.application.credentials.api_static_key &&
          error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.invalid_token'))

        cmd_authenticator = CmdAuthenticateUser.new(params['e'], params['p']).call
        error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => cmd_authenticator.errors[:msg].join('; ')) unless cmd_authenticator.success?

        { msg: I18n.t('api.message.generic_ok'), jwt: cmd_authenticator.result }
      end
    end
  end
end
