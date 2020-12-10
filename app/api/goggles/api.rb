# frozen_string_literal: true

require 'version'
require 'audit_formatter'
require 'grape_logging'

module Goggles
  # = Goggles main API v3 Grape controller
  #
  # Mounts all required API modules
  #
  #   - version:  1.09
  #   - author:   Steve A.
  #   - build:    20201207
  #
  class API < Grape::API
    helpers APIHelpers

    version      'v3', using: :path, vendor: 'goggles'
    prefix       :api
    format       :json
    content_type :json, 'application/json'

    # Audit log setup:
    logger = Logger.new('log/api_audit.log', 10, 1_024_000)
    logger.formatter = AuditFormatter.new
    use GrapeLogging::Middleware::RequestLogger, {
      logger: logger,
      include: [
        GrapeLogging::Loggers::Response.new,
        GrapeLogging::Loggers::FilterParameters.new,
        GrapeLogging::Loggers::ClientEnv.new,
        GrapeLogging::Loggers::RequestHeaders.new
      ]
    }
    #-- -----------------------------------------------------------------------
    #++

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
        {
          msg: I18n.t("api.message.status.#{GogglesDb::AppParameter.maintenance? ? 'maintenance' : 'ok'}"),
          version: Version::FULL
        }
      end
    end

    mount BadgesAPI
    mount LookupAPI
    mount SeasonsAPI
    mount SessionAPI
    mount SwimmersAPI
    mount SwimmingPoolsAPI
    mount TeamAffiliationsAPI
    mount TeamsAPI
    mount UsersAPI
  end
end
