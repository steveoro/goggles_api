# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingProgram API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
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
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

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
        optional :standard_timing_id, type: Integer, desc: 'optional: link to StandardTiming'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          meeting_program = GogglesDb::MeetingProgram.find_by(id: params['id'])
          meeting_program&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_program
      #
      # Creates a new MeetingProgram row given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - meeting_event_id: associated MeetingEvent ID
      # - event_order: ordinal number of this program
      # - pool_type_id: associated PoolType ID
      # - gender_type_id: associated GenderType ID
      # - category_type_id: associated CategoryType ID
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingProgram row'
      params do
        requires :meeting_event_id, type: Integer, desc: 'link to MeetingEvent'
        requires :event_order, type: Integer, desc: 'ordinal number of this program'
        requires :pool_type_id, type: Integer, desc: 'link to PoolType'
        requires :gender_type_id, type: Integer, desc: 'link to GenderType'
        requires :category_type_id, type: Integer, desc: 'link to CategoryType'
        optional :begin_time, type: String, desc: 'optional: begin time for this program (parsed with Time.zone, based on year 2000)'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this program does not concur in the overall rankings or scores'
        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :standard_timing_id, type: Integer, desc: 'optional: link to StandardTiming'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::MeetingProgram.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_program/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingProgram'
      params do
        requires :id, type: Integer, desc: 'MeetingProgram ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::MeetingProgram.exists?(params['id'])

          GogglesDb::MeetingProgram.destroy(params['id']).destroyed?
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
                                   .order('meeting_programs.id DESC')
        )
      end
    end
  end
end
