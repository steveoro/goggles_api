# frozen_string_literal: true

require 'version'
require 'audit_formatter'
require 'grape_logging'
require 'grape-swagger/entity'

# = Goggles main API v3 Grape controller
#
# Mounts all required API modules
#
# - version:  7-0.7.10
# - author:   Steve A.
# - build:    20240425
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
      logger:,
      include: [
        GrapeLogging::Loggers::Response.new,
        GrapeLogging::Loggers::FilterParameters.new,
        GrapeLogging::Loggers::ClientEnv.new,
        GrapeLogging::Loggers::RequestHeaders.new
      ]
    }
    #-- -----------------------------------------------------------------------
    #++

    if Rails.env.local?
      before do
        Prosopite.scan
      end

      finally do
        Prosopite.finish
      end
    end
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
      desc "Returns the API 'msg' status and the current application versioning code" do
        success Goggles::Entities::StatusEntity
      end
      get do
        payload = {
          msg: I18n.t("api.message.status.#{GogglesDb::AppParameter.maintenance? ? 'maintenance' : 'ok'}"),
          version: Version::FULL
        }

        present payload, with: Goggles::Entities::StatusEntity
      end
    end

    mount AdminGrantsAPI
    mount APIDailyUsesAPI
    mount BadgesAPI
    mount BadgePaymentsAPI
    mount CalendarsAPI
    mount CategoryTypesAPI
    mount CitiesAPI
    mount FederationTypesAPI
    mount ImportQueuesAPI
    mount IndividualRecordsAPI
    mount IssuesAPI
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
    mount MeetingSessionsAPI
    mount RelayLapsAPI
    mount SeasonTypesAPI
    mount SeasonsAPI
    mount SessionAPI
    mount SettingsAPI
    mount StandardTimingsAPI
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

    add_swagger_documentation(
      api_version: 'v3',
      hide_documentation_path: true,
      mount_path: '/swagger_doc',
      models: [
        Goggles::Entities::AdminGrantEntity,
        Goggles::Entities::APIDailyUseEntity,
        Goggles::Entities::BadgeEntity,
        Goggles::Entities::BadgePaymentEntity,
        Goggles::Entities::CalendarEntity,
        Goggles::Entities::CategoryTypeEntity,
        Goggles::Entities::CityEntity,
        Goggles::Entities::FederationTypeEntity,
        Goggles::Entities::ImportQueueEntity,
        Goggles::Entities::IndividualRecordEntity,
        Goggles::Entities::IssueEntity,
        Goggles::Entities::LapEntity,
        Goggles::Entities::LookupEntity,
        Goggles::Entities::ManagedAffiliationEntity,
        Goggles::Entities::MeetingEntity,
        Goggles::Entities::MeetingEntryEntity,
        Goggles::Entities::MeetingEventEntity,
        Goggles::Entities::MeetingIndividualResultEntity,
        Goggles::Entities::MeetingProgramEntity,
        Goggles::Entities::MeetingRelayResultEntity,
        Goggles::Entities::MeetingRelaySwimmerEntity,
        Goggles::Entities::MeetingReservationEntity,
        Goggles::Entities::MeetingSessionEntity,
        Goggles::Entities::RelayLapEntity,
        Goggles::Entities::SeasonEntity,
        Goggles::Entities::SeasonTypeEntity,
        Goggles::Entities::SessionEntity,
        Goggles::Entities::StandardTimingEntity,
        Goggles::Entities::StatusEntity,
        Goggles::Entities::SwimmerEntity,
        Goggles::Entities::SwimmingPoolEntity,
        Goggles::Entities::TeamAffiliationEntity,
        Goggles::Entities::TeamEntity,
        Goggles::Entities::UserEntity,
        Goggles::Entities::UserLapEntity,
        Goggles::Entities::UserResultEntity,
        Goggles::Entities::UserWorkshopEntity
      ],
      info: {
        title: 'Goggles API',
        description: 'Backend API for the Goggles framework',
        contact_name: 'Goggles Team',
        version: Version::SEMANTIC
      },
      schemes: %w[http https],
      security_definitions: {
        Bearer: {
          type: 'apiKey',
          name: 'Authorization',
          in: 'header',
          description: 'JWT token in format: Bearer <token>'
        }
      },
      security: [{ Bearer: [] }]
    )
  end
end
