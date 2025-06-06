# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Tools API: EntryTime finder
  #
  #   - version:  7-0.8.00
  #   - author:   Steve A.
  #   - build:    20241223
  #
  class ToolsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

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
      desc 'Find suggested entry time'
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
      desc 'Compute result score or target timing, depending on the parameters supplied'
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
      desc 'Retrieve latest updates x main entities'
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
    end
  end
end
