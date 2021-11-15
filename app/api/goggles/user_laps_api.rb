# frozen_string_literal: true

module Goggles
  # = Goggles API v3: UserLap API Grape controller
  #
  #   - version:  7-0.3.39
  #   - author:   Steve A.
  #   - build:    20211115
  #
  # == Note:
  # Unlike MIRs-vs.-MRRs, UserResults can be used for both individuals *and* relays.
  # A UserLap row can bind different swimmers to each lap as UserResults can be created
  # for any type of event.
  #
  # See GogglesDb::UserLap && GogglesDb::UserResult for more info.
  #
  class UserLapsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :user_lap do
      # GET /api/:version/user_lap/:id
      #
      # == Returns:
      # The UserLap instance matching the specified +id+ as JSON.
      # See GogglesDb::UserLap#to_json for structure details.
      #
      desc 'UserLap details'
      params do
        requires :id, type: Integer, desc: 'UserLap ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::UserLap.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/user_lap/:id
      #
      # Allow direct update for all the UserLap fields.
      # Requires CRUD grant on entity ('UserLap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update UserLap details'
      params do
        requires :id, type: Integer, desc: 'UserLap ID'
        optional :user_result_id, type: Integer, desc: 'optional: associated UserResult ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: user_lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: user_lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: user_lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: user_lap length in meters'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the user_lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundredths_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'UserLap')

          user_lap = GogglesDb::UserLap.find_by(id: params['id'])
          user_lap&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/user_lap
      # Requires CRUD grant on entity ('UserLap') for requesting user.
      #
      # Creates a new UserLap given the specified parameters.
      #
      # == Required params:
      # - user_result_id
      # - swimmer_id
      #
      # Timing can be set by either one of these tuples:
      # - lap / relative => ( [reaction_time] minutes seconds hundredths )
      # - lap / absolute => ( [reaction_time] minutes_from_start seconds_from_start hundredths_from_start )
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new UserLap'
      params do
        requires :user_result_id, type: Integer, desc: 'associated UserResult ID'
        requires :swimmer_id, type: Integer, desc: 'associated Swimmer ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: user_lap time, minutes'
        optional :seconds, type: Integer, desc: 'optional: user_lap time, seconds'
        optional :hundredths, type: Integer, desc: 'optional: user_lap time, hundredths of seconds'
        optional :length_in_meters, type: Integer, desc: 'optional: user_lap length in meters'
        optional :position, type: Integer, desc: 'optional: heat position at the end of the user_lap'
        optional :minutes_from_start, type: Integer, desc: 'optional: overall minutes from heat start'
        optional :seconds_from_start, type: Integer, desc: 'optional: overall seconds from heat start'
        optional :hundredths_from_start, type: Integer, desc: 'optional: overall hundredths of second from heat start'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'UserLap')

        new_row = GogglesDb::UserLap.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/user_lap/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('UserLap') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a UserLap'
      params do
        requires :id, type: Integer, desc: 'UserLap ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'UserLap')

          return unless GogglesDb::UserLap.exists?(params['id'])

          GogglesDb::UserLap.destroy(params['id']).destroyed?
        end
      end
    end

    resource :user_laps do
      # GET /api/:version/user_laps
      #
      # Given some optional filtering parameters, returns the paginated list of user_laps found.
      #
      # == Returns:
      # The list of UserLaps for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::UserLap#to_json for structure details.
      #
      desc 'List UserLaps'
      params do
        optional :user_result_id, type: Integer, desc: 'optional: associated UserResult ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::UserLap.where(filtering_hash_for(params, %w[user_result_id swimmer_id]))
        )
      end
    end
  end
end
