# frozen_string_literal: true

module Goggles
  # = Goggles API v3: UserResult API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  # == Note:
  # Unlike MIRs-vs.-MRRs, UserResults can be used for both individuals *and* relays.
  # A UserLap row can bind different swimmers to each lap as UserResults can be created
  # for any type of event.
  #
  # See GogglesDb::UserLap && GogglesDb::UserResult for more info.
  #
  class UserResultsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :user_result do
      # GET /api/:version/user_result/:id
      #
      # == Returns:
      # The UserResult instance matching the specified +id+ as JSON.
      # See GogglesDb::UserResult#to_json for structure details.
      #
      desc 'UserResult details'
      params do
        requires :id, type: Integer, desc: 'UserResult ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::UserResult.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/user_result/:id
      #
      # Allow direct update for all the UserResult fields.
      # Requires CRUD grant on entity ('UserResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update UserResult details'
      params do
        requires :id, type: Integer, desc: 'UserResult ID'
        optional :user_id, type: Integer, desc: 'optional: associated User ID (creator/recorder)'
        optional :user_workshop_id, type: Integer, desc: 'optional: associated UserWorkshop ID'
        optional :event_date, type: Date, desc: 'optional: date for the event/result'
        optional :description, type: String, desc: 'optional: description for this event/result'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :swimming_pool_id, type: Integer, desc: 'optional: associated SwimmingPool ID'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'

        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundredths, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :disqualified, type: Boolean, desc: 'optional: true if the swimmer has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'UserResult')

          user_result = GogglesDb::UserResult.find_by(id: params['id'])
          user_result&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/user_result
      # Requires CRUD grant on entity ('UserResult') for requesting user.
      #
      # Creates a new UserResult given the specified parameters.
      #
      # == Required params:
      # - user_id
      # - user_workshop_id
      # - event_date
      # - pool_type_id
      # - event_type_id
      # - category_type_id
      #
      # Timing result defaults to zero. Results can be created even when the actual result time
      # is not known yet.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new UserResult'
      params do
        requires :user_id, type: Integer, desc: 'associated User ID (creator/recorder)'
        requires :user_workshop_id, type: Integer, desc: 'associated UserWorkshop ID'
        requires :event_date, type: Date, desc: 'date for the event/result'
        requires :pool_type_id, type: Integer, desc: 'associated PoolType ID'
        requires :event_type_id, type: Integer, desc: 'associated EventType ID'
        requires :category_type_id, type: Integer, desc: 'associated CategoryType ID'

        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID (or default swimmer for the laps)'
        optional :description, type: String, desc: 'optional: description for this event/result'
        optional :swimming_pool_id, type: Integer, desc: 'optional: associated SwimmingPool ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundredths, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :disqualified, type: Boolean, desc: 'optional: true if the swimmer has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'UserResult')

        new_row = GogglesDb::UserResult.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/user_result/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('UserResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a UserResult'
      params do
        requires :id, type: Integer, desc: 'UserResult ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'UserResult')

          return unless GogglesDb::UserResult.exists?(params['id'])

          GogglesDb::UserResult.destroy(params['id']).destroyed?
        end
      end
    end

    resource :user_results do
      # GET /api/:version/user_results
      #
      # Given some optional filtering parameters, returns the paginated list of user_results found.
      #
      # == Returns:
      # The list of UserResults for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::UserResult#to_json for structure details.
      #
      desc 'List UserResults'
      params do
        optional :user_id, type: Integer, desc: 'optional: associated User ID (creator/recorder)'
        optional :user_workshop_id, type: Integer, desc: 'optional: associated UserWorkshop ID'
        optional :event_date, type: Date, desc: 'optional: date for the event/result'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID (or default swimmer for the laps)'
        optional :description, type: String, desc: 'optional: description for this event/result'
        optional :swimming_pool_id, type: Integer, desc: 'optional: associated SwimmingPool ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::UserResult.where(
            filtering_hash_for(
              params,
              %w[user_id user_workshop_id event_date pool_type_id event_type_id
                 category_type_id swimmer_id swimming_pool_id]
            )
          ).where(
            filtering_like_for(params, %w[description])
          )
          .order('user_results.id DESC')
        ).map(&:to_hash)
      end
    end
  end
end
