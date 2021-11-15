# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Session API Grape controller
  #
  #   - version:  7-0.2.18
  #   - author:   Steve A.
  #   - build:    20210518
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
      # This endpoint will refuse to create new JWT sessions if the server is in maintenance.
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

        # New API session should be disabled during maintenance (only admin users can continue).
        # Retrieve the API user and check the grants:
        decoded_jwt_data = GogglesDb::JWTManager.decode(cmd_authenticator.result, Rails.application.credentials.api_static_key)
        api_user = GogglesDb::User.find_by(id: decoded_jwt_data[:user_id]) if decoded_jwt_data
        reject_during_maintenance(api_user)

        # Update stats using as key a path stripped of all IDs & return authorization result:
        # (Note: for some tests negative IDs may be used, so we consider those too)
        GogglesDb::APIDailyUse.increase_for!("#{request.env['REQUEST_METHOD']} #{request.path.gsub(%r{/-?\d+}, '/:id')}")

        { msg: I18n.t('api.message.generic_ok'), jwt: cmd_authenticator.result }
      end
    end
  end
end
