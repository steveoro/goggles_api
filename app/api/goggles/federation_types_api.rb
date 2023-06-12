# frozen_string_literal: true

module Goggles
  # = Goggles API v3: FederationType API Grape controller
  #
  #   - version:  7-0.3.37
  #   - author:   Steve A.
  #   - build:    20211109
  #
  class FederationTypesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :federation_type do
      # GET /api/:version/federation_type/:id
      #
      # == Returns:
      # The FederationType instance matching the specified +id+ as JSON.
      # See GogglesDb::FederationType#to_json for structure details.
      #
      desc 'FederationType details'
      params do
        requires :id, type: Integer, desc: 'FederationType ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::FederationType.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/federation_type/:id
      #
      # Allows direct update for most of the FederationType fields.
      # 'code' and 'season' are not editable.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update FederationType details'
      params do
        requires :id, type: Integer, desc: 'FederationType ID'
        optional :code, type: String, desc: 'optional: internal (federation) code'
        optional :description, type: String, desc: 'optional: Federation type description'
        optional :short_name, type: String, desc: 'optional: short Federation type name'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          federation_type = GogglesDb::FederationType.find_by(id: params['id'])
          federation_type&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/federation_type
      #
      # Creates a new FederationType given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - code
      # - description
      # - short_name
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new FederationType'
      params do
        requires :code, type: String, desc: 'internal code'
        requires :description, type: String, desc: 'Federation type description'
        requires :short_name, type: String, desc: 'short Federation type name'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::FederationType.create(params)
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

    resource :federation_types do
      # GET /api/:version/federation_types
      #
      # Given some optional filtering parameters, returns the paginated list of federation_types found.
      #
      # == Returns:
      # The list of FederationTypes for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::FederationType#to_json for structure details.
      #
      desc 'List FederationTypes'
      params do
        optional :code, type: String, desc: 'optional: internal code'
        optional :description, type: String, desc: 'optional: Federation type description'
        optional :short_name, type: String, desc: 'optional: short Federation type name'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::FederationType.where(
            filtering_like_for(params, %w[code short_name group_name description])
          )
        ).map(&:to_hash)
      end
    end
  end
end
