# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingSession API Grape controller
  #
  #   - version:  7-0.3.46
  #   - author:   Steve A.
  #   - build:    20220307
  #
  class MeetingSessionsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_session do
      # GET /api/:version/meeting_session/:id
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The MeetingSession instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingSession#to_json for structure details.
      #
      desc 'MeetingSession details'
      params do
        requires :id, type: Integer, desc: 'MeetingSession ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          reject_unless_authorized_admin(check_jwt_session)

          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::MeetingSession.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_session/:id
      #
      # Allows direct update for all the MeetingSession fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingSession details'
      params do
        requires :id, type: Integer, desc: 'MeetingSession ID'
        optional :scheduled_date, type: String, desc: 'optional: schedule date for this session of the Meeting in ISO format'
        optional :session_order, type: Integer, desc: 'optional: numerical order of the session, starting from 1'
        optional :description, type: String, desc: 'optional: description of the session'
        optional :warm_up_time, type: String, desc: 'optional: warm-up hour for this session in ISO format (HH:MM)'
        optional :begin_time, type: String, desc: 'optional: event start hour for this session in ISO format (HH:MM)'
        optional :notes, type: String, desc: 'optional: free text notes'
        optional :meeting_id, type: Integer, desc: 'optional: associated Meeting ID'
        optional :swimming_pool_id, type: Integer, desc: 'optional: associated SwimmingPool ID'
        optional :autofilled, type: Boolean, desc: 'optional: true if the values were autofilled by the data-import procedure'
        optional :day_part_type_id, type: Integer, desc: 'optional: associated DayPartType ID (morning, afternoon, evening)'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          meeting_session = GogglesDb::MeetingSession.find_by(id: params['id'])
          meeting_session&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_session
      #
      # Creates a new MeetingSession row given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - scheduled_date: schedule date for this session of the Meeting in ISO format
      # - meeting_id: associated Meeting ID
      # - session_order: numerical order of the session, starting from 1
      # - description: description of the session
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingSession row'
      params do
        requires :scheduled_date, type: String, desc: 'schedule date for this session of the Meeting in ISO format'
        requires :meeting_id, type: Integer, desc: 'associated Meeting ID'
        requires :session_order, type: Integer, desc: 'numerical order of the session, starting from 1'
        requires :description, type: String, desc: 'description of the session'
        optional :warm_up_time, type: String, desc: 'optional: warm-up hour for this session in ISO format (HH:MM)'
        optional :begin_time, type: String, desc: 'optional: event start hour for this session in ISO format (HH:MM)'
        optional :notes, type: String, desc: 'optional: free text notes'
        optional :swimming_pool_id, type: Integer, desc: 'optional: associated SwimmingPool ID'
        optional :autofilled, type: Boolean, desc: 'optional: true if the values were autofilled by the data-import procedure'
        optional :day_part_type_id, type: Integer, desc: 'optional: associated DayPartType ID (morning, afternoon, evening)'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::MeetingSession.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_session/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingSession'
      params do
        requires :id, type: Integer, desc: 'MeetingSession ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::MeetingSession.exists?(params['id'])

          GogglesDb::MeetingSession.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_sessions do
      # GET /api/:version/meeting_sessions
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_sessions found.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The list of MeetingSessions for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingSession#to_json for structure details.
      #
      desc 'List MeetingSessions'
      params do
        optional :scheduled_date, type: String, desc: 'optional: schedule date for this session of the Meeting in ISO format'
        optional :meeting_id, type: Integer, desc: 'optional: associated Meeting ID'
        optional :autofilled, type: Boolean, desc: 'optional: true if the values were autofilled by the data-import procedure'
        use :pagination
      end
      paginate
      get do
        reject_unless_authorized_admin(check_jwt_session)

        paginate(GogglesDb::MeetingSession.where(filtering_hash_for(params, %w[scheduled_date meeting_id autofilled])))
      end
    end
  end
end
