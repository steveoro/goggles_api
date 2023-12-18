# frozen_string_literal: true

module Goggles
  # = Goggles API v3: RelayLap API Grape controller
  #
  #   - version:  7-0.6.10
  #   - author:   Steve A.
  #   - build:    20231218
  #
  class RelayLapsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :relay_lap do
      # GET /api/:version/relay_lap/:id
      #
      # == Returns:
      # The RelayLap instance matching the specified +id+ as JSON.
      # See GogglesDb::RelayLap#to_json for structure details.
      #
      desc 'RelayLap details'
      params do
        requires :id, type: Integer, desc: 'RelayLap ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::RelayLap.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/relay_lap/:id
      #
      # Allow direct update for all the RelayLap fields.
      # Requires CRUD grant on entity ('RelayLap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update RelayLap details'
      params do
        requires :id, type: Integer, desc: 'RelayLap ID'
        optional :meeting_relay_result_id, type: Integer, desc: 'optional: associated MeetingRelayResult ID'
        optional :meeting_relay_swimmer_id, type: Integer, desc: 'optional: associated MeetingRelaySwimmer ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: relay_lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: relay_lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: relay_lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: relay_lap length in meters'
        optional :stroke_cycles, type: Integer, desc: 'optional: relay_lap overall stroke cycles'
        optional :breath_cycles, type: Integer, desc: 'optional: relay_lap overall breath cycles'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the relay_lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundredths_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'RelayLap')

          relay_lap = GogglesDb::RelayLap.find_by(id: params['id'])
          relay_lap&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/relay_lap
      # Requires CRUD grant on entity ('RelayLap') for requesting user.
      #
      # Creates a new RelayLap given the specified parameters.
      #
      # == Required params:
      # - meeting_program_id (required)
      # - team_id (required)
      # - swimmer_id (required)
      #
      # Association with MIR is optional to allow relay_lap creation even before
      # the heat is over. RelayLap timing will be ignored on display if it's not positive.
      #
      # Timing can be set by either one of these tuples:
      # - relay_lap-relative:( [reaction_time] minutes seconds hundredths )
      # - relay_lap-absolute: ( [reaction_time] minutes_from_start seconds_from_start hundredths_from_start )
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new RelayLap'
      params do
        requires :meeting_relay_result_id, type: Integer, desc: 'associated MeetingRelayResult ID'
        requires :meeting_relay_swimmer_id, type: Integer, desc: 'associated MeetingRelaySwimmer ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        requires :swimmer_id, type: Integer, desc: 'associated Swimmer ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: relay_lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: relay_lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: relay_lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: relay_lap length in meters'
        optional :stroke_cycles, type: Integer, desc: 'optional: relay_lap overall stroke cycles'
        optional :breath_cycles, type: Integer, desc: 'optional: relay_lap overall breath cycles'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the relay_lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundredths_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'RelayLap')

        new_row = GogglesDb::RelayLap.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/relay_lap/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('RelayLap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a RelayLap'
      params do
        requires :id, type: Integer, desc: 'RelayLap ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'RelayLap')

          return unless GogglesDb::RelayLap.exists?(params['id'])

          GogglesDb::RelayLap.destroy(params['id']).destroyed?
        end
      end
    end

    resource :relay_laps do
      # GET /api/:version/relay_laps
      #
      # Given some optional filtering parameters, returns the paginated list of relay_laps found.
      #
      # == Returns:
      # The list of RelayLaps for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::RelayLap#to_json for structure details.
      #
      desc 'List RelayLaps'
      params do
        optional :meeting_relay_result_id, type: Integer, desc: 'optional: associated MeetingRelayResult ID'
        optional :meeting_relay_swimmer_id, type: Integer, desc: 'optional: associated MeetingRelaySwimmer ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::RelayLap.where(
            filtering_hash_for(params, %w[meeting_relay_result_id meeting_relay_swimmer_id team_id swimmer_id])
          )
        ).map(&:to_hash)
      end
    end
  end
end
