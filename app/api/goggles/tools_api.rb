# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Tools API: EntryTime finder
  #
  #   - version:  7.061
  #   - author:   Steve A.
  #   - build:    20210119
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
      # - GogglesDb::TimingFinders::Factory
      # - GogglesDb::CmdFindEntryTime
      #
      # == Params:
      # - swimmer_id
      # - meeting_id (optional)
      # - event_type_id
      # - pool_type_id
      # - entry_time_type_id (optional)
      #
      # == Returns:
      #
      # The suggested entry time as JSON, both as a single text label ("label")
      # and as individual 'timing' fields (see below).
      #
      # On error returns just the zeroed label (signaling "no time") without the 'timing' instance part.
      #
      # == Sample structure:
      # (Currently, for legacy reasons "hundreds" stands obviously for "hundredths")
      #
      #   {
      #     "label": "1'17\"47",
      #     "timing": {
      #       "hundreds": 47, "seconds": 17, "minutes": 1, "hours": 0, "days": 0
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
        meeting         = GogglesDb::Meeting.find_by_id(params['meeting_id'])
        event_type      = reject_unless_found(params['event_type_id'], GogglesDb::EventType)
        pool_type       = reject_unless_found(params['pool_type_id'], GogglesDb::PoolType)
        entry_time_type = GogglesDb::EntryTimeType.find_by_id(params['entry_time_type_id'])

        command = if entry_time_type
                    GogglesDb::CmdFindEntryTime.call(swimmer, meeting, event_type, pool_type, entry_time_type)
                  else # use default retrieval strategy:
                    GogglesDb::CmdFindEntryTime.call(swimmer, meeting, event_type, pool_type)
                  end

        return { 'label': '0\'00"00', errors: command.errors } unless command.success? # (no timing instance included in result upon failure)

        { 'label': command.result.to_s, 'timing': command.result } if command.success?
      end
    end
  end
end
