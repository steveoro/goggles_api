# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Tools API: EntryTime finder
  #
  #   - version:  7-0.10.82
  #   - author:   Steve A.
  #   - build:    20261124
  #
  class ToolsAPI < Grape::API # rubocop:disable Metrics/ClassLength
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    # Tables reported by GET tools/db_fingerprint (import-owned and user-touched ones);
    # any other table name is rejected.
    DB_FINGERPRINT_TABLES = %w[
      meetings meeting_sessions meeting_events meeting_programs
      meeting_individual_results meeting_relay_results meeting_relay_swimmers
      laps relay_laps meeting_team_scores
      swimmers teams team_affiliations badges
      calendars swimming_pools cities managed_affiliations
      standard_timings category_types users
    ].freeze

    # Server-side cache duration for each distinct set of fingerprint parameters:
    DB_FINGERPRINT_CACHE_TTL = 60.seconds

    helpers do
      # Returns the sorted list of whitelisted table names requested with the comma-separated
      # +tables_param+ (all of them when blank); yields a 422 error for any unknown name.
      def db_fingerprint_tables(tables_param)
        requested = tables_param.to_s.split(',').map(&:strip).compact_blank.uniq
        return DB_FINGERPRINT_TABLES.sort if requested.empty?

        unknown = requested - DB_FINGERPRINT_TABLES
        if unknown.present?
          error!(I18n.t('api.message.invalid_parameter'), 422,
                 'X-Error-Detail' => "unsupported tables: #{unknown.join(', ')}; allowed: #{DB_FINGERPRINT_TABLES.join(', ')}")
        end
        requested.sort
      end

      # Returns the DB fingerprint Hash for the specified +tables+ (see GET tools/db_fingerprint).
      def db_fingerprint_payload(tables, light)
        {
          environment: Rails.env.to_s,
          generated_at: Time.now.utc.iso8601,
          schema_version: ActiveRecord::Base.connection_pool.migration_context.current_version.to_s,
          db_version: db_fingerprint_db_version,
          import_queue: db_fingerprint_import_queue,
          tables: tables.index_with { |table_name| light ? db_light_fingerprint_for(table_name) : db_full_fingerprint_for(table_name) }
        }
      end

      # DB data version stored in the versioning parameter row (or the framework one, if missing).
      def db_fingerprint_db_version
        versioning_row = GogglesDb::AppParameter.find_by(code: GogglesDb::AppParameter::VERSIONING_CODE)
        versioning_row&.read_attribute(GogglesDb::AppParameter::DB_VERSION_FIELDNAME).presence || Version::DB
      end

      # Import-queue summary: next auto-increment ID and the unfinished batch SQL rows,
      # split between queued (or running) and failed ones.
      def db_fingerprint_import_queue
        unfinished_batch_rows = GogglesDb::ImportQueue.with_batch_sql.where(done: false)
        {
          next_id: db_next_auto_increment_id(GogglesDb::ImportQueue.table_name),
          batch_queued: unfinished_batch_rows.where(error_messages: [nil, '']).count,
          batch_failed: unfinished_batch_rows.where.not(error_messages: [nil, '']).count
        }
      end

      def db_next_auto_increment_id(table_name)
        connection = ActiveRecord::Base.connection
        next_id = connection.select_value(
          ActiveRecord::Base.sanitize_sql_array(
            ['SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', table_name]
          )
        )
        next_id.present? ? next_id.to_i : connection.select_value("SELECT MAX(id) FROM #{connection.quote_table_name(table_name)}").to_i + 1
      end

      # Full mode: row count, max ID and max updated_at (one table scan).
      def db_full_fingerprint_for(table_name)
        connection = ActiveRecord::Base.connection
        row = connection.select_one(
          'SELECT COUNT(*) AS row_count, MAX(id) AS max_id, MAX(updated_at) AS max_updated_at ' \
          "FROM #{connection.quote_table_name(table_name)}"
        )
        {
          count: row['row_count'].to_i,
          max_id: row['max_id']&.to_i,
          max_updated_at: db_fingerprint_timestamp(row['max_updated_at'])
        }
      end

      # Light mode: max ID only (primary key index lookup).
      def db_light_fingerprint_for(table_name)
        connection = ActiveRecord::Base.connection
        { max_id: connection.select_value("SELECT MAX(id) FROM #{connection.quote_table_name(table_name)}")&.to_i }
      end

      def db_fingerprint_timestamp(value)
        return if value.blank?

        (value.respond_to?(:utc) ? value : Time.zone.parse(value.to_s))&.utc&.iso8601
      end
    end

    resource :tools do
      # GET /api/:version/tools/find_entry_time
      #
      # Returns the suggested entry time given the specified parameters (see below).
      # For more details on the actual strategy used, see:
      # - <tt>GogglesDb::TimingFinders::Factory</tt>
      # - <tt>GogglesDb::CmdFindEntryTime</tt>
      #
      # == Params:
      # - <tt>swimmer_id</tt>
      # - <tt>meeting_id</tt> (optional)
      # - <tt>event_type_id</tt>
      # - <tt>pool_type_id</tt>
      # - <tt>entry_time_type_id</tt> (optional)
      #
      # == Returns:
      #
      # The suggested entry time as JSON, both as a single text label ("label")
      # and as individual 'timing' fields (see below).
      #
      # On error returns just the zeroed label (signaling "no time") without the 'timing' instance part.
      #
      # == Sample structure:
      #
      #   {
      #     "label": "1'17\"47",
      #     "timing": {
      #       "hundredths": 47, "seconds": 17, "minutes": 1, "hours": 0, "days": 0
      #     }
      #   }
      #
      desc 'Find suggested entry time' do
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :swimmer_id, type: Integer, desc: 'Swimmer ID registering for the meeting entry'
        optional :meeting_id, type: Integer, desc: 'optional: Meeting ID (when available)'
        requires :event_type_id, type: Integer, desc: 'EventType ID associated with the event'
        requires :pool_type_id, type: Integer, desc: 'PoolType ID associated with the event'
        optional :entry_time_type_id, type: Integer, desc: 'EntryTimeType ID for the meeting entry'
      end
      get :find_entry_time do
        check_jwt_session

        # Retrieve values:
        swimmer         = reject_unless_found(params['swimmer_id'], GogglesDb::Swimmer)
        meeting         = GogglesDb::Meeting.find_by(id: params['meeting_id'])
        event_type      = reject_unless_found(params['event_type_id'], GogglesDb::EventType)
        pool_type       = reject_unless_found(params['pool_type_id'], GogglesDb::PoolType)
        entry_time_type = GogglesDb::EntryTimeType.find_by(id: params['entry_time_type_id'])

        command = if entry_time_type
                    GogglesDb::CmdFindEntryTime.call(swimmer, meeting, event_type, pool_type, entry_time_type)
                  else # use default retrieval strategy:
                    GogglesDb::CmdFindEntryTime.call(swimmer, meeting, event_type, pool_type)
                  end

        return { label: '0\'00"00', errors: command.errors } unless command.success? # (no timing instance included in result upon failure)

        { label: command.result.to_s, timing: command.result } if command.success?
      end
      #-- ---------------------------------------------------------------------
      #++

      # GET /api/:version/tools/compute_score
      #
      # Computes either the resulting score given a specific timing or the target
      # timing itself given the resulting score, depending on which parameter is supplied.
      #
      # For more details on the actual strategy used, see:
      # - <tt>GogglesDb::Calculators::Factory</tt>
      # - <tt>GogglesDb::CmdSelectScoreCalculator</tt>
      # - <tt>GogglesDb::Calculators::BaseStrategy</tt>
      #
      # == Params:
      # - <tt>pool_type_id</tt>
      # - <tt>event_type_id</tt>
      #
      # Plus, at least:
      # - <tt>badge_id</tt> (optional)
      # - <tt>hundredths</tt> (optional, is +score+ is specified)
      # - <tt>seconds</tt> (optional, is +score+ is specified)
      # - <tt>minutes</tt> (optional, is +score +is specified)
      # - <tt>score</tt> (optional, if all the timing parameters are supplied)
      #
      # Or, alternatively, all these:
      # - <tt>season_id</tt> (optional, if the <tt>badge_id</tt> is supplied)
      # - <tt>gender_type_id</tt> (optional, if the <tt>badge_id</tt> is supplied)
      # - <tt>category_type_id</tt> (optional, if the <tt>badge_id</tt> is supplied)
      #
      # Optional override:
      # - <tt>standard_points</tt> (optional, defaults to 1000)
      #
      # == Returns:
      #
      # A zero score on error, a positive floating value otherwise.
      # The resulting score or target timing will be stored inside the following
      # JSON structure:
      #
      #   {
      #     # Result or target score (depending on the parameters supplied):
      #     "score": 845.65,
      #
      #     # Result or target timing (as above):
      #     "timing": {
      #       "hundredths": 47, "seconds": 5, "minutes": 2, "hours": 0, "days": 0
      #     },
      #     "timing_label": "2'05\"47",
      #
      #     "standard_points": 1000.0,
      #     "display_label": "MS 4x50 SL [25 M] - 200-239, FIN MASTER 2019/2020, MIX",
      #     "short_label": "MS 4x50 SL [25 M] - 200-239 MIX",
      #     "standard_timing_label": "1'48\"79",
      #     "standard_timing": {
      #       "id": 16509,
      #       "minutes": 1, "seconds": 48, "hundredths": 79,
      #       "season_id": 192, "gender_type_id": 3,
      #       "pool_type_id": 1, "event_type_id": 32,
      #       "category_type_id": 1309,
      #       # [...]
      #      }
      #   }
      #
      desc 'Compute result score or target timing, depending on the parameters supplied' do
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :pool_type_id, type: Integer, desc: 'PoolType ID for the event'
        requires :event_type_id, type: Integer, desc: 'EventType ID for the event'

        optional :minutes, type: Integer, desc: 'optional: target or result time minutes (required when the target score has to be computed)'
        optional :seconds, type: Integer, desc: 'optional: target or result time seconds (required when the target score has to be computed)'
        optional :hundredths, type: Integer, desc: 'optional: target or result time hundredths of seconds (required to compute the target score)'
        optional :score, type: Integer, desc: 'optional: target score (required when the target timing is desired)'
        optional :standard_points, type: Integer, desc: 'optional: standard base points override; default: 1000'

        optional :badge_id, type: Integer, desc: 'optional: Badge ID (as alternative instead of Season + Gender + Category)'
        optional :season_id, type: Integer, desc: 'optional: Season ID for the event (as alternative instead of Badge)'
        optional :gender_type_id, type: Integer, desc: 'optional: GenderType ID for the event (as alternative instead of Badge)'
        optional :category_type_id, type: Integer, desc: 'optional: CategoryType ID for the event (as alternative instead of Badge)'
      end
      get :compute_score do
        check_jwt_session

        # Retrieve values:
        pool_type  = reject_unless_found(params['pool_type_id'], GogglesDb::PoolType)
        event_type = reject_unless_found(params['event_type_id'], GogglesDb::EventType)
        timing = Timing.new(minutes: params['minutes'], seconds: params['seconds'], hundredths: params['hundredths'])
        target_score = params['score']
        standard_points = params['standard_points'] || 1000.0

        badge = GogglesDb::Badge.find_by(id: params['badge_id'])
        season = GogglesDb::Season.find_by(id: params['season_id'])
        gender_type = GogglesDb::GenderType.find_by(id: params['gender_type_id'])
        category_type = GogglesDb::CategoryType.find_by(id: params['category_type_id'])

        command = GogglesDb::CmdSelectScoreCalculator.call(
          pool_type:, event_type:, badge:,
          season:, gender_type:, category_type:
        )

        return { score: 0, timing: timing.to_json, errors: command.errors } unless command.success?

        score_value = command.result.compute_for(timing, standard_points:) if timing.present?
        timing = command.result.timing_from(target_score.to_i) if target_score.present?
        standard_timing = command.result.standard_timing

        {
          score: score_value || target_score,
          timing_label: timing.to_s,
          timing:,
          standard_points:,
          display_label: standard_timing&.decorate&.display_label,
          short_label: standard_timing&.decorate&.short_label,
          standard_timing_label: standard_timing&.to_timing.to_s,
          standard_timing:
        }
      end
      #-- ---------------------------------------------------------------------
      #++

      # GET /api/:version/tools/latest_updates
      #
      # Returns the an array of rows detailing the <tt>max</tt> (default: 3) latest updated
      # data rows found for:
      #
      # - <tt>GogglesDb::Calendar</tt>
      # - <tt>GogglesDb::Meeting</tt>
      # - <tt>GogglesDb::MeetingIndividualResult</tt>
      # - <tt>GogglesDb::MeetingRelayResult</tt>
      # - <tt>GogglesDb::Lap</tt>
      # - <tt>GogglesDb::RelayLap</tt>
      # - <tt>GogglesDb::MeetingEvent</tt>
      # - <tt>GogglesDb::MeetingProgram</tt>
      # - <tt>GogglesDb::Badge</tt>
      # - <tt>GogglesDb::Swimmer</tt>
      # - <tt>GogglesDb::Team</tt>
      #
      # == Params:
      # - <tt>max</tt>: maximum number of rows retrieved x entity; default: 3 (optional);
      #   max value allowed: 10
      #
      # == Returns:
      #
      # A JSON object with table names as keys pointing to an array of rows with the top 3 or 4
      # most significant fields. Example structure:
      #
      #   {
      #     "calendars": [
      #       {
      #         "id": <id>,
      #         "updated_at": <timestamp>,
      #         "description": <description>,
      #         "meeting_id": <meeting_id>
      #       },
      #       ...
      #     ],
      #     "meetings": [
      #       {
      #         "id": <id>,
      #         "updated_at": <timestamp>,
      #         "description": <description>,
      #         "season_id": <season_id>
      #       },
      #       ...
      #     ],
      #     ...
      #   }
      #
      desc 'Retrieve latest updates x main entities' do
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        optional :max, type: Integer, desc: 'Maximum number or rows x main entities (default: 3; max allowed: 10)'
      end
      get :latest_updates do
        check_jwt_session

        max_rows = params['max'] || 3
        max_rows = 10 if max_rows.to_i < 1 || max_rows.to_i > 10
        result = {}
        {
          GogglesDb::Calendar => %w[id updated_at description meeting_id],
          GogglesDb::Meeting => %w[id updated_at description season_id],
          GogglesDb::MeetingIndividualResult => %w[id updated_at meeting_program_id swimmer_id],
          GogglesDb::MeetingRelayResult => %w[id updated_at meeting_program_id team_id],
          GogglesDb::Lap => %w[id updated_at meeting_individual_result_id],
          GogglesDb::RelayLap => %w[id updated_at meeting_relay_result_id],
          GogglesDb::MeetingEvent => %w[id updated_at meeting_session_id],
          GogglesDb::MeetingProgram => %w[id updated_at meeting_event_id],
          GogglesDb::Swimmer => %w[id updated_at complete_name year_of_birth],
          GogglesDb::Team => %w[id updated_at name],
          GogglesDb::Badge => %w[id updated_at swimmer_id team_id],
          GogglesDb::TeamAffiliation => %w[id updated_at team_id season_id]
        }.each do |entity, col_names|
          result[entity.table_name] = entity.order(updated_at: :desc, id: :desc).limit(max_rows)
                                            .map { |row| row.attributes.keep_if { |col, _v| col_names.include?(col) } }
        end

        result
      end
      #-- ---------------------------------------------------------------------
      #++

      # GET /api/:version/tools/db_fingerprint
      #
      # Returns a "fingerprint" of the DB contents (count & max ID x table), used by
      # goggles_admin2 to check whether its local DB still mirrors this one.
      # Requires Admin grants for the requesting user.
      #
      # Only the tables in DB_FINGERPRINT_TABLES are supported (422 + 'X-Error-Detail' otherwise).
      # Results are cached server-side for DB_FINGERPRINT_CACHE_TTL for each distinct set of parameters
      # ('generated_at' tells when the values were computed).
      #
      # == Params:
      # - tables: optional, comma-separated list of table names (default: all supported tables)
      # - light: optional, when true ('1') reports just the max ID of each table (PK index lookup only)
      #
      # == Returns:
      #
      #   {
      #     "environment": "production", "generated_at": "2026-11-22T10:00:00Z",
      #     "schema_version": "20261027120100", "db_version": "2.10.12",
      #     "import_queue": { "next_id": 9124, "batch_queued": 0, "batch_failed": 0 },
      #     "tables": {
      #       "laps": { "count": 4120331, "max_id": 4188002, "max_updated_at": "2026-11-22T09:58:12Z" },
      #       ...
      #     }
      #   }
      #
      # In light mode each "tables.<name>" value is just <tt>{ "max_id": <n> }</tt>.
      #
      desc 'DB fingerprint: count, max ID & max updated_at x supported table (admin only)' do
        success Goggles::Entities::DbFingerprintEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [422, 'Unprocessable entity - Unsupported table name(s) (see X-Error-Detail)']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        optional :tables, type: String, desc: "optional: comma-separated table names (default: all supported: #{DB_FINGERPRINT_TABLES.join(', ')})"
        optional :light, type: Boolean, desc: 'optional: true (1) to report just the max ID x table (no count, no max updated_at)'
      end
      get :db_fingerprint do
        reject_unless_authorized_admin(check_jwt_session)

        tables = db_fingerprint_tables(params['tables'])
        light = params['light'] == true
        payload = Rails.cache.fetch(['db_fingerprint', tables.join(','), light], expires_in: DB_FINGERPRINT_CACHE_TTL) do
          db_fingerprint_payload(tables, light)
        end

        present payload, with: Goggles::Entities::DbFingerprintEntity
      end
      #-- ---------------------------------------------------------------------
      #++
    end
  end
end
