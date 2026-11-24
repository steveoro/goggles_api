# frozen_string_literal: true

require 'version'
require 'audit_formatter'
require 'grape_logging'
require 'grape-swagger/entity'

# = Goggles main API v3 Grape controller
#
# Mounts all required API modules
#
# - version:  7-0.10.82
# - author:   Steve A.
# - build:    20261124
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

    # Feature flags advertised by GET status, so that clients (e.g. goggles_admin2) can
    # detect what this server supports and fall back gracefully when talking to an older one:
    #
    # - 'iq_batch_outcome': batch SQL import-queue rows report their outcome (applied/failed + error text)
    #                       and expose their data file name/checksum/size; a failed row blocks the later ones;
    # - 'iq_batch_filters': GET import_queues supports the 'batch_sql' & 'done' (also when false) filters;
    # - 'db_fingerprint':   GET tools/db_fingerprint is available.
    CAPABILITIES = %w[iq_batch_outcome iq_batch_filters db_fingerprint].freeze

    resource :status do
      # GET /api/:version/status
      #
      # == Returns:
      # A JSON hash with a +msg+, the running +version+ of the application framework,
      # the Rails +environment+ name and the list of supported +capabilities+.
      #
      #   {
      #     msg: <status message>, version: <versioning & build number>,
      #     environment: <'production', 'development', ...>, capabilities: [<feature flag>, ...]
      #   }
      #
      desc "Returns the API 'msg' status, the current application versioning code, environment and capabilities" do
        success Goggles::Entities::StatusEntity
      end
      get do
        payload = {
          msg: I18n.t("api.message.status.#{GogglesDb::AppParameter.maintenance? ? 'maintenance' : 'ok'}"),
          version: Version::FULL,
          environment: Rails.env.to_s,
          capabilities: CAPABILITIES
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
    mount GoggleCupsAPI
    mount GoggleCupManageAPI
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
    mount TrainingsAPI
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
        Goggles::Entities::DbFingerprintEntity,
        Goggles::Entities::FederationTypeEntity,
        Goggles::Entities::GoggleCupEntity,
        Goggles::Entities::GogglesCup3yBaseTimingsEntity,
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
        Goggles::Entities::TrainingEntity,
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
