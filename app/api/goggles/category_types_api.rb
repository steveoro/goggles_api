# frozen_string_literal: true

module Goggles
  # = Goggles API v3: CategoryType API Grape controller
  #
  #   - version:  7.02.18
  #   - author:   Steve A.
  #   - build:    20210519
  #
  class CategoryTypesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :category_type do
      # GET /api/:version/category_type/:id
      #
      # == Returns:
      # The CategoryType instance matching the specified +id+ as JSON.
      # See GogglesDb::CategoryType#to_json for structure details.
      #
      desc 'CategoryType details'
      params do
        requires :id, type: Integer, desc: 'CategoryType ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::CategoryType.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/category_type/:id
      #
      # Allows direct update for most of the CategoryType fields.
      # 'code' and 'season' are not editable.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update CategoryType details'
      params do
        requires :id, type: Integer, desc: 'CategoryType ID'
        optional :federation_code, type: String, desc: 'optional: federation code for this category'
        optional :description, type: String, desc: 'optional: category description'
        optional :short_name, type: String, desc: 'optional: short category name'
        optional :group_name, type: String, desc: 'optional: category group name'
        optional :age_begin, type: Integer, desc: 'optional: age group start'
        optional :age_end, type: Integer, desc: 'optional: age group end'
        optional :relay, type: Boolean, desc: 'optional: true for relay categories'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this category does not concur in the overall ranking'
        optional :undivided, type: Boolean, desc: 'optional: true for categories that do not use gender splitting'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          category_type = GogglesDb::CategoryType.find_by_id(params['id'])
          category_type&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/category_type
      #
      # Creates a new CategoryType given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - code
      # - season_id
      # - short_name
      # - group_name
      # - age_begin
      # - age_end
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new CategoryType'
      params do
        requires :code, type: String, desc: 'internal code'
        requires :season_id, type: Integer, desc: 'associated Season ID'
        requires :short_name, type: String, desc: 'short category name'
        requires :group_name, type: String, desc: 'category group name'
        requires :age_begin, type: Integer, desc: 'age group end'
        requires :age_end, type: Integer, desc: 'age group start'
        optional :federation_code, type: String, desc: 'optional: federation code for this category'
        optional :description, type: String, desc: 'optional: category description'
        optional :relay, type: Boolean, desc: 'optional: true for relay categories'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this category does not concur in the overall ranking'
        optional :undivided, type: Boolean, desc: 'optional: true for categories that do not use gender splitting'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::CategoryType.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/category_type/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a CategoryType'
      params do
        requires :id, type: Integer, desc: 'CategoryType ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::CategoryType.exists?(params['id'])

          GogglesDb::CategoryType.destroy(params['id']).destroyed?
        end
      end
    end

    resource :category_types do
      # GET /api/:version/category_types
      #
      # Given some optional filtering parameters, returns the paginated list of category_types found.
      #
      # *Supports the bespoke "Select2 option" output format*
      #
      # == Returns:
      # The list of CategoryTypes for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::CategoryType#to_json for structure details.
      #
      desc 'List CategoryTypes'
      params do
        optional :code, type: String, desc: 'optional: internal code'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :short_name, type: String, desc: 'optional: short category name'
        optional :group_name, type: String, desc: 'optional: category group name'
        optional :age_begin, type: Integer, desc: 'optional: age group start'
        optional :age_end, type: Integer, desc: 'optional: age group end'
        optional :federation_code, type: String, desc: 'optional: federation code for this category'
        optional :description, type: String, desc: 'optional: category description'
        optional :relay, type: Boolean, desc: 'optional: true for relay categories'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this category does not concur in the overall ranking'
        optional :undivided, type: Boolean, desc: 'optional: true for categories that do not use gender splitting'
        optional :select2_format, type: Boolean, desc: 'optional: true to enable the simplified (id+text) Select2 output format'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        results = GogglesDb::CategoryType.where(
          filtering_hash_for(params, %w[season_id age_begin age_end federation_code relay out_of_race undivided])
        ).where(
          filtering_like_for(params, %w[code short_name group_name description])
        )

        if params['select2_format'] == true
          select2_custom_format(results, ->(row) { "#{row.code} (#{row.description})" })
        else
          paginate(results)
        end
      end
    end
  end
end
