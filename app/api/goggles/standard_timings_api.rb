# frozen_string_literal: true

module Goggles
  # = Goggles API v3: StandardTiming API Grape controller
  #
  #   - version:  7-0.3.39
  #   - author:   Steve A.
  #   - build:    20211115
  #
  class StandardTimingsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :standard_timing do
      # GET /api/:version/standard_timing/:id
      #
      # == Returns:
      # The StandardTiming instance matching the specified +id+ as JSON.
      # See GogglesDb::StandardTiming#to_json for structure details.
      #
      desc 'StandardTiming details'
      params do
        requires :id, type: Integer, desc: 'StandardTiming ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::StandardTiming.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/standard_timing/:id
      #
      # Allows direct update for all the StandardTiming fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update StandardTiming details'
      params do
        requires :id, type: Integer, desc: 'StandardTiming ID'
        optional :minutes, type: Integer, desc: 'optional: minutes value for this standard timing'
        optional :seconds, type: Integer, desc: 'optional: seconds value for this standard timing'
        optional :hundredths, type: Integer, desc: 'optional: hundredths of seconds value for this standard timing'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          standard_timing = GogglesDb::StandardTiming.find_by(id: params['id'])
          standard_timing&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/standard_timing
      #
      # Creates a new StandardTiming given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - minutes, seconds & hundredths: the timing values
      # - season_id: the associated Season ID
      # - gender_type_id: the associated GenderType ID
      # - pool_type_id: the associated PoolType ID
      # - event_type_id: the associated EventType ID
      # - category_type_id: the  associated CategoryType ID
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new StandardTiming'
      params do
        requires :minutes, type: Integer, desc: 'minutes value for this standard timing'
        requires :seconds, type: Integer, desc: 'seconds value for this standard timing'
        requires :hundredths, type: Integer, desc: 'hundredths of seconds value for this standard timing'
        requires :season_id, type: Integer, desc: 'associated Season ID'
        requires :gender_type_id, type: Integer, desc: 'associated GenderType ID'
        requires :pool_type_id, type: Integer, desc: 'associated PoolType ID'
        requires :event_type_id, type: Integer, desc: 'associated EventType ID'
        requires :category_type_id, type: Integer, desc: 'associated CategoryType ID'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::StandardTiming.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/standard_timing/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a StandardTiming'
      params do
        requires :id, type: Integer, desc: 'StandardTiming ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::StandardTiming.exists?(params['id'])

          GogglesDb::StandardTiming.destroy(params['id']).destroyed?
        end
      end
    end

    resource :standard_timings do
      # GET /api/:version/standard_timings
      #
      # Given some optional filtering parameters, returns the paginated list of standard_timings found.
      #
      # == Returns:
      # The list of StandardTimings for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::StandardTiming#to_json for structure details.
      #
      desc 'List StandardTimings'
      params do
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::StandardTiming.where(
            filtering_hash_for(params, %w[season_id gender_type_id pool_type_id event_type_id category_type_id])
          )
        )
      end
    end
  end
end
