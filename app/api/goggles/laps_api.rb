# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Lap API Grape controller
  #
  #   - version:  7.067
  #   - author:   Steve A.
  #   - build:    20210122
  #
  # == Note:
  # Laps can be only assigned to MIRs; for MRRs use MeetingRelaySwimmers for lap data.
  #
  # See GogglesDb::Lap & GogglesDb::MeetingRelaySwimmer for more info.
  #
  class LapsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :lap do
      # GET /api/:version/lap/:id
      #
      # == Returns:
      # The Lap instance matching the specified +id+ as JSON.
      # See GogglesDb::Lap#to_json for structure details.
      #
      desc 'Lap details'
      params do
        requires :id, type: Integer, desc: 'Lap ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Lap.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/lap/:id
      #
      # Allow direct update for all the Lap fields.
      # Requires CRUD grant on entity ('Lap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Lap details'
      params do
        requires :id, type: Integer, desc: 'Lap ID'
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MeetingIndividualResult ID'
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: lap time, seconds'
        optional :hundreds, type: Integer, desc: 'optional: lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: lap length in meters'
        optional :stroke_cycles, type: Integer, desc: 'optional: lap overall stroke cycles'
        optional :underwater_seconds, type: Integer, desc: 'optional: time spent underwater on turn/start, seconds'
        optional :underwater_hundreds, type: Integer, desc: 'optional: time spent underwater on turn/start, hundredths of a second'
        optional :underwater_kicks, type: Integer, desc: 'optional: underwater kicks after lap turn/start'
        optional :breath_cycles, type: Integer, desc: 'optional: lap overall breath cycles'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundreds_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Lap')

          lap = GogglesDb::Lap.find_by_id(params['id'])
          lap&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/lap
      # Requires CRUD grant on entity ('Lap') for requesting user.
      #
      # Creates a new Lap given the specified parameters.
      #
      # == Required params:
      # - meeting_program_id (required)
      # - team_id (required)
      # - swimmer_id (required)
      #
      # Association with MIR is optional to allow lap creation even before
      # the heat is over. Lap timing will be ignored on display if it's not positive.
      #
      # Timing can be set by either one of these tuples:
      # - lap-relative:( [reaction_time] minutes seconds hundreds )
      # - lap-absolute: ( [reaction_time] minutes_from_start seconds_from_start hundreds_from_start )
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new Lap'
      params do
        requires :meeting_program_id, type: Integer, desc: 'associated MeetingProgram ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        requires :swimmer_id, type: Integer, desc: 'associated Swimmer ID'
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MeetingIndividualResult ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: lap time, seconds'
        optional :hundreds, type: Integer, desc: 'optional: lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: lap length in meters'
        optional :stroke_cycles, type: Integer, desc: 'optional: lap overall stroke cycles'
        optional :underwater_seconds, type: Integer, desc: 'optional: time spent underwater on turn/start, seconds'
        optional :underwater_hundreds, type: Integer, desc: 'optional: time spent underwater on turn/start, hundredths of a second'
        optional :underwater_kicks, type: Integer, desc: 'optional: underwater kicks after lap turn/start'
        optional :breath_cycles, type: Integer, desc: 'optional: lap overall breath cycles'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundreds_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'Lap')

        new_row = GogglesDb::Lap.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            500,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/lap/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('Lap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a Lap'
      params do
        requires :id, type: Integer, desc: 'Lap ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Lap')

          return unless GogglesDb::Lap.exists?(params['id'])

          GogglesDb::Lap.destroy(params['id']).destroyed?
        end
      end
    end

    resource :laps do
      # GET /api/:version/laps
      #
      # Given some optional filtering parameters, returns the paginated list of laps found.
      #
      # == Returns:
      # The list of Laps for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Lap#to_json for structure details.
      #
      desc 'List Laps'
      params do
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MeetingIndividualResult ID'
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::Lap.where(
            filtering_hash_for(params, %w[meeting_individual_result_id meeting_program_id team_id swimmer_id])
          )
        )
      end
    end
  end
end
