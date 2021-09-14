# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingProgram API Grape controller
  #
  #   - version:  7.0.3.30
  #   - author:   Steve A.
  #   - build:    20210914
  #
  class MeetingProgramsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_program do
      # GET /api/:version/meeting_program/:id
      #
      # == Returns:
      # The MeetingProgram instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingProgram#to_json for structure details.
      #
      desc 'MeetingProgram details'
      params do
        requires :id, type: Integer, desc: 'MeetingProgram ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::MeetingProgram.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_program/:id
      #
      # Allows direct update for most of the MeetingProgram fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingProgram details'
      params do
        requires :id, type: Integer, desc: 'MeetingProgram ID'
        optional :event_order, type: Integer, desc: 'optional: ordinal number of this program'
        optional :category_type_id, type: Integer, desc: 'optional: link to CategoryType'
        optional :gender_type_id, type: Integer, desc: 'optional: link to GenderType'
        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this program does not concur in the overall rankings or scores'
        optional :begin_time, type: String, desc: 'optional: begin time for this program (parsed with Time.zone, based on year 2000)'
        optional :meeting_event_id, type: Integer, desc: 'optional: link to MeetingEvent'
        optional :pool_type_id, type: Integer, desc: 'optional: link to PoolType'
        # TODO: add the following after the next GogglesDb life cycle (w/ standard_timing migration fix)
        # optional :standard_timing_id, type: Integer, desc: 'optional: link to TimeStandard'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          meeting_program = GogglesDb::MeetingProgram.find_by(id: params['id'])
          meeting_program&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :meeting_programs do
      # GET /api/:version/meeting_programs
      #
      # Given a *required* meeting_id plus other optional filtering parameters,
      # this will return the paginated list of MeetingPrograms found for the specified values.
      #
      # == Returns:
      # The list of MeetingPrograms for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for all parameter values.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingProgram#to_json for structure details.
      #
      desc 'List MeetingPrograms'
      params do
        requires :meeting_id, type: Integer, desc: 'associated Meeting ID'
        optional :meeting_session_id, type: Integer, desc: 'optional: associated MeetingSession ID'
        optional :meeting_event_id, type: Integer, desc: 'optional: associated MeetingEvent ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        filtering_conditions = { 'meetings.id': params['meeting_id'] }
        filtering_conditions.merge!('meeting_sessions.id': params['meeting_session_id']) if params['meeting_session_id'].present?
        filtering_conditions.merge!(filtering_hash_for(params, %w[meeting_event_id category_type_id gender_type_id]) || {})

        paginate(
          GogglesDb::MeetingProgram.joins(:meeting, :meeting_session)
                                   .includes(:meeting, :meeting_session)
                                   .where(
                                     ActiveRecord::Base.sanitize_sql_for_conditions(filtering_conditions)
                                   )
        )
      end
    end
  end
end
