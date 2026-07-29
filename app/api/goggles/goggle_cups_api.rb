# frozen_string_literal: true

module Goggles
  # = Goggles API v3: GoggleCup API Grape controller
  #
  #   - version:  7-0.9.14
  #   - author:   Steve A.
  #   - build:    20260729
  #
  class GoggleCupsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :goggle_cup do
      # GET /api/:version/goggle_cup/:id
      #
      # == Returns:
      # The GoggleCup instance matching the specified +id+ as JSON; an empty result when not found.
      # See GogglesDb::GoggleCup#to_json for structure details.
      #
      desc 'GoggleCup details' do
        success Goggles::Entities::GoggleCupEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::GoggleCup.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/goggle_cup/:id
      #
      # Allow direct update for the GoggleCup fields.
      # Requires CRUD grant on entity ('GoggleCup') for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update GoggleCup details' do
        success code: 200, message: 'GoggleCup updated'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
        optional :description, type: String, desc: 'GoggleCup description'
        optional :season_year, type: Integer, desc: 'Season year'
        optional :max_points, type: Integer, desc: 'Maximum points for the GoggleCup'
        optional :team_id, type: Integer, desc: 'Associated Team ID'
        optional :end_date, type: Date, desc: 'End date'
        optional :team_constrained, type: Boolean, desc: 'True if the GoggleCup is constrained to the team'
        optional :swimmers_ids, type: String, desc: 'Comma-separated list of swimmer IDs'
        optional :ranking_data, type: String, desc: 'Stringified JSON object with ranking data'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'GoggleCup')

          goggle_cup = GogglesDb::GoggleCup.find_by(id: params['id'])
          goggle_cup&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/goggle_cup
      # (ADMIN only)
      #
      # Creates a new GoggleCup given the specified parameters.
      #
      # == Required Params:
      # - description (required)
      # - season_year (required)
      # - team_id (required)
      #
      # == Optional Params:
      # - max_points
      # - end_date
      # - team_constrained
      # - swimmers_ids
      # - ranking_data
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new GoggleCup' do
        success code: 201, message: 'GoggleCup created'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [422, 'Unprocessable entity - Validation failure']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :description, type: String, desc: 'GoggleCup description (required)'
        requires :season_year, type: Integer, desc: 'Season year (required)'
        requires :team_id, type: Integer, desc: 'Associated Team ID (required)'
        optional :max_points, type: Integer, desc: 'Maximum points for the GoggleCup'
        optional :end_date, type: Date, desc: 'End date'
        optional :team_constrained, type: Boolean, desc: 'True if the GoggleCup is constrained to the team'
        optional :swimmers_ids, type: String, desc: 'Comma-separated list of swimmer IDs'
        optional :ranking_data, type: String, desc: 'Stringified JSON object with ranking data'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)

        new_row = GogglesDb::GoggleCup.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/goggle_cup/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a GoggleCup' do
        success code: 200, message: 'GoggleCup deleted'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::GoggleCup.exists?(params['id'])

          GogglesDb::GoggleCup.destroy(params['id']).destroyed?
        end
      end
    end

    resource :goggle_cups do
      # GET /api/:version/goggle_cups
      #
      # Given some optional filtering parameters, returns the paginated list of GoggleCups found.
      #
      # == Returns:
      # The list of GoggleCups for the specified filtering parameters as an array of JSON objects.
      # Returns only *exact* matches, no fuzzy or partial searches are done.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::GoggleCup#to_json for structure details.
      #
      desc 'List GoggleCups' do
        is_array true
        success Goggles::Entities::GoggleCupEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        optional :team_id, type: Integer, desc: 'associated Team ID'
        optional :season_year, type: Integer, desc: 'Season year'
        use :pagination
      end
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate per_page: 50
      get do
        check_jwt_session

        paginate(GogglesDb::GoggleCup.includes(:team).where(
          filtering_hash_for(
            params,
            %w[team_id season_year]
          )
        ).order('goggle_cups.id DESC')).map(&:to_hash)
      end

      # GET /api/:version/goggle_cups/search
      #
      # Search existing GoggleCups by description (LIKE), optionally filtered by team_id and/or season_year.
      #
      # == Returns:
      # The matching list of GoggleCups as an array of JSON objects.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      desc 'Search GoggleCups by description' do
        is_array true
        success Goggles::Entities::GoggleCupEntity
        failure [
          [400, 'Bad request - Missing required search parameters'],
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :description, type: String, desc: 'GoggleCup description (partial match)'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :season_year, type: Integer, desc: 'optional: Season year'
        use :pagination
      end
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate per_page: 50
      get :search do
        check_jwt_session

        results = GogglesDb::GoggleCup.includes(:team)
                                      .where(filtering_like_for(params, %w[description]))
                                      .where(filtering_hash_for(params, %w[team_id season_year]))
                                      .order('goggle_cups.id DESC')

        paginate(results).map(&:to_hash)
      end
    end
  end
end
