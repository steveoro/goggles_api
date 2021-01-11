# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingEvent API Grape controller
  #
  #   - version:  7.060
  #   - author:   Steve A.
  #   - build:    20210111
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

          GogglesDb::MeetingEvent.find_by_id(params['id'])
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
