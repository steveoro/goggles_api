# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingRelaySwimmer API Grape controller
  #
  #   - version:  7-0.3.39
  #   - author:   Steve A.
  #   - build:    20211115
  #
  # == Note:
  # MeetingRelaySwimmers store lap data for MRRs.
  #
  class MeetingRelaySwimmersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_relay_swimmer do
      # GET /api/:version/meeting_relay_swimmer/:id
      #
      # == Returns:
      # The MeetingRelaySwimmer instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingRelaySwimmer#to_json for structure details.
      #
      desc 'MeetingRelaySwimmer details'
      params do
        requires :id, type: Integer, desc: 'MeetingRelaySwimmer ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::MeetingRelaySwimmer.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_relay_swimmer/:id
      #
      # Allow direct update for all the MeetingRelaySwimmer fields.
      # Requires CRUD grant on entity ('MeetingRelaySwimmer') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingRelaySwimmer details'
      params do
        requires :id, type: Integer, desc: 'MeetingRelaySwimmer ID'
        optional :meeting_relay_result_id, type: Integer, desc: 'optional: associated MeetingRelayResult ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :stroke_type_id, type: Integer, desc: 'optional: associated StrokeType ID'
        optional :relay_order, type: Integer, desc: 'optional: swimmer ordering inside relay (starting position)'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: lap time, hundredths of seconds'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingRelaySwimmer')

          meeting_relay_swimmer = GogglesDb::MeetingRelaySwimmer.find_by(id: params['id'])
          meeting_relay_swimmer&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_relay_swimmer
      # Requires CRUD grant on entity ('MeetingRelaySwimmer') for requesting user.
      #
      # Creates a new MeetingRelaySwimmer given the specified parameters.
      #
      # == Required params:
      # - meeting_relay_result_id
      # - swimmer_id
      # - badge_id
      # - stroke_type_id
      # - relay_order
      #
      # Timing can be set by either one of these tuples:
      # - meeting_relay_swimmer-relative:( [reaction_time] minutes seconds hundredths )
      # - meeting_relay_swimmer-absolute: ( [reaction_time] minutes_from_start seconds_from_start hundredths_from_start )
      #
      # When not set, timing will default to zero and shall be ignored on display.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingRelaySwimmer'
      params do
        requires :meeting_relay_result_id, type: Integer, desc: 'required: associated MeetingRelayResult ID'
        requires :swimmer_id, type: Integer, desc: 'required: associated Swimmer ID'
        requires :badge_id, type: Integer, desc: 'required: associated Badge ID'
        requires :stroke_type_id, type: Integer, desc: 'required: associated StrokeType ID'
        requires :relay_order, type: Integer, desc: 'required: swimmer ordering inside relay (starting position)'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: lap time, hundredths of seconds'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'MeetingRelaySwimmer')

        new_row = GogglesDb::MeetingRelaySwimmer.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_relay_swimmer/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('MeetingRelaySwimmer') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingRelaySwimmer'
      params do
        requires :id, type: Integer, desc: 'MeetingRelaySwimmer ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingRelaySwimmer')

          return unless GogglesDb::MeetingRelaySwimmer.exists?(params['id'])

          GogglesDb::MeetingRelaySwimmer.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_relay_swimmers do
      # GET /api/:version/meeting_relay_swimmers
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_relay_swimmers found.
      #
      # == Returns:
      # The list of MeetingRelaySwimmers for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingRelaySwimmer#to_json for structure details.
      #
      desc 'List MeetingRelaySwimmers'
      params do
        optional :meeting_relay_result_id, type: Integer, desc: 'optional: associated MeetingRelayResult ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :stroke_type_id, type: Integer, desc: 'optional: associated StrokeType ID'
        optional :relay_order, type: Integer, desc: 'optional: swimmer ordering inside relay (starting position)'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::MeetingRelaySwimmer.where(
            filtering_hash_for(params, %w[meeting_relay_result_id swimmer_id badge_id stroke_type_id relay_order])
          )
        )
      end
    end
  end
end
