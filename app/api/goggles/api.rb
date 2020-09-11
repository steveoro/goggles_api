# frozen_string_literal: true

require 'version'

module Goggles
  # = Goggles main API v3 Grape controller
  #
  # Mounts all required API modules
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200910
  #
  class API < Grape::API
    version      'v3', using: :path, vendor: 'goggles'
    prefix       :api
    format       :json
    content_type :json, 'application/json'

    resource :status do
      # GET /api/:version/status
      #
      # == Returns:
      # A JSON hash with a +msg+ and the running +version+ of the application framework.
      #
      #   { msg: <status message>, version: <versioning & build number> }
      #
      desc "Returns the API 'msg' status and the current application versioning code"
      get do
        { msg: I18n.t('api.message.status.ok'), version: Version::FULL }
      end
    end

    mount UsersAPI
  end
end
