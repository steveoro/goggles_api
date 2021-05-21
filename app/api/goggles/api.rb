# frozen_string_literal: true

require 'version'
require 'audit_formatter'
require 'grape_logging'

# = Goggles main API v3 Grape controller
#
# Mounts all required API modules
#
#   - version:  7.02.18
#   - author:   Steve A.
#   - build:    20210521
#
module Goggles
  # = Goggles::API
  #
  # Master API container.
  #
  # Configures the API logger, implements the status endpoint
  # and mounts all API subclasses.
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

    mount APIDailyUsesAPI
    mount BadgesAPI
    mount CategoryTypesAPI
    mount CitiesAPI
    mount ImportQueuesAPI
    mount LapsAPI
    mount LookupAPI
    mount MeetingsAPI
    mount MeetingEntriesAPI
    mount MeetingEventsAPI
    mount MeetingIndividualResultsAPI
    mount MeetingProgramsAPI
    mount MeetingRelayResultsAPI
    mount MeetingRelaySwimmersAPI
    mount MeetingReservationsAPI
    mount SeasonsAPI
    mount SessionAPI
    mount SwimmersAPI
    mount SwimmingPoolsAPI
    mount TeamAffiliationsAPI
    mount TeamManagersAPI
    mount TeamsAPI
    mount ToolsAPI
    mount UserLapsAPI
    mount UserResultsAPI
    mount UserWorkshopsAPI
    mount UsersAPI
  end
end
