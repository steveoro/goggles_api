# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingEvent API Grape controller
  #
  #   - version:  7.0.3.30
  #   - author:   Steve A.
  #   - build:    20210914
  #
  class MeetingEventsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_event do
      # GET /api/:version/meeting_event/:id
      #
      # == Returns:
      # The MeetingEvent instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingEvent#to_json for structure details.
      #
      desc 'MeetingEvent details'
      params do
        requires :id, type: Integer, desc: 'MeetingEvent ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::MeetingEvent.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_event/:id
      #
      # Allows direct update for most of the MeetingEvent fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingEvent details'
      params do
        requires :id, type: Integer, desc: 'MeetingEvent ID'
        optional :event_order, type: Integer, desc: 'optional: ordinal number of this event'
        optional :begin_time, type: String, desc: 'optional: begin time for this event (parsed with Time.zone, based on year 2000)'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this event does not concur in the overall rankings or scores'
        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :notes, type: String, desc: 'optional: free notes about this event'
        optional :meeting_session_id, type: Integer, desc: 'optional: link to MeetingSession'
        optional :event_type_id, type: Integer, desc: 'optional: link to EventType'
        optional :heat_type_id, type: Integer, desc: 'optional: link to HeatType'
        optional :split_gender_start_list, type: Boolean, desc: 'optional: true if this event splits gender'
        optional :split_category_start_list, type: Boolean, desc: 'optional: true if this event splits category'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          meeting_event = GogglesDb::MeetingEvent.find_by(id: params['id'])
          meeting_event&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :meeting_events do
      # GET /api/:version/meeting_events
      #
      # Given a *required* meeting_id plus an optional meeting_session_id
      # as filtering parameters, this will return the paginated list of
      # meeting_events found for the specified values.
      #
      # == Returns:
      # The list of MeetingEvents for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for all parameter values.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingEvent#to_json for structure details.
      #
      desc 'List MeetingEvents'
      params do
        requires :meeting_id, type: Integer, desc: 'associated Meeting ID'
        optional :meeting_session_id, type: Integer, desc: 'optional: associated MeetingSession ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        filtering_conditions = { 'meetings.id': params['meeting_id'] }
        filtering_conditions.merge!('meeting_sessions.id': params['meeting_session_id']) if params['meeting_session_id'].present?

        paginate(
          GogglesDb::MeetingEvent.joins(:meeting, :meeting_session)
                                 .includes(:meeting, :meeting_session)
                                 .where(
                                   ActiveRecord::Base.sanitize_sql_for_conditions(filtering_conditions)
                                 )
        )
      end
    end
  end
end
