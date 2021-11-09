# frozen_string_literal: true

module Goggles
  # = Goggles API v3: SeasonType API Grape controller
  #
  #   - version:  7-0.3.37
  #   - author:   Steve A.
  #   - build:    20211109
  #
  class SeasonTypesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :season_type do
      # GET /api/:version/season_type/:id
      #
      # == Returns:
      # The SeasonType instance matching the specified +id+ as JSON.
      # See GogglesDb::SeasonType#to_json for structure details.
      #
      desc 'SeasonType details'
      params do
        requires :id, type: Integer, desc: 'SeasonType ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::SeasonType.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/season_type/:id
      #
      # Allows direct update for most of the SeasonType fields.
      # 'code' and 'season' are not editable.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update SeasonType details'
      params do
        requires :id, type: Integer, desc: 'SeasonType ID'
        optional :code, type: String, desc: 'optional: internal code'
        optional :federation_type_id, type: Integer, desc: 'optional: associated FederationType ID'
        optional :short_name, type: String, desc: 'optional: short category name'
        optional :description, type: String, desc: 'optional: category description'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          season_type = GogglesDb::SeasonType.find_by(id: params['id'])
          season_type&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/season_type
      #
      # Creates a new SeasonType given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - code
      # - description
      # - short_name
      # - federation_type_id
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new SeasonType'
      params do
        requires :code, type: String, desc: 'internal code'
        requires :federation_type_id, type: Integer, desc: 'associated FederationType ID'
        requires :description, type: String, desc: 'optional: Season type description'
        requires :short_name, type: String, desc: 'short Season type name'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::SeasonType.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end
    end

    resource :season_types do
      # GET /api/:version/season_types
      #
      # Given some optional filtering parameters, returns the paginated list of season_types found.
      #
      # == Returns:
      # The list of SeasonTypes for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::SeasonType#to_json for structure details.
      #
      desc 'List SeasonTypes'
      params do
        optional :code, type: String, desc: 'optional: internal code'
        optional :federation_type_id, type: Integer, desc: 'optional: associated FederationType ID'
        optional :short_name, type: String, desc: 'optional: short category name'
        optional :description, type: String, desc: 'optional: category description'

        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::SeasonType.where(
            filtering_hash_for(params, %w[federation_type_id])
          ).where(
            filtering_like_for(params, %w[code short_name description])
          )
        )
      end
    end
  end
end
