# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Issue API Grape controller
  #
  #   - version:  7-0.5.01
  #   - author:   Steve A.
  #   - build:    20230404
  #
  # Implements full CRUD interface for Issue.
  #
  class IssuesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :issue do
      # GET /api/:version/issue/:id
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The Issue instance matching the specified +id+ as JSON.
      # See GogglesDb::Issue#to_json for structure details.
      #
      desc 'Issue details'
      params do
        requires :id, type: Integer, desc: 'Issue ID'
      end
      route_param :id do
        get do
          reject_unless_authorized_admin(check_jwt_session)

          GogglesDb::Issue.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/issue/:id
      #
      # Allow direct update for most of the Issue fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Issue details'
      params do
        requires :id, type: Integer, desc: 'Issue ID'
        optional :req, type: String, desc: 'optional: parsable JSON request, enlisting all required parameters at hash root level'
        optional :priority, type: Integer, desc: 'optional: request priority (0..3)'
        optional :status, type: Integer, desc: 'optional: request status (processable: 0..3, solved/rejected: 4..6)'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          issue = GogglesDb::Issue.find_by(id: params['id'])
          issue&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/issue
      #
      # Creates a new Issue given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Params:
      # - user_id (required)
      # - code (required)
      # - req (required)
      # - priority
      # - status
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new Issue'
      params do
        requires :user_id, type: Integer, desc: 'associated User ID'
        requires :code, type: String, desc: 'issue code type (max 3 chars; see [goggles_db] Issue model for details)'
        requires :req, type: String, desc: 'parsable JSON request, enlisting all required parameters at hash root level'
        optional :priority, type: Integer, desc: 'optional: request priority (0..3)'
        optional :status, type: Integer, desc: 'optional: request status (processable: 0..3, solved/rejected: 4..6)'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::Issue.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/issue/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a Issue'
      params do
        requires :id, type: Integer, desc: 'Issue ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::Issue.exists?(params['id'])

          GogglesDb::Issue.destroy(params['id']).destroyed?
        end
      end
    end

    resource :issues do
      # GET /api/:version/issues
      #
      # Given some optional filtering parameters, returns the paginated list of issues found.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The list of Issues for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Issue#to_json for structure details.
      #
      desc 'List Issues'
      params do
        optional :user_id, type: Integer, desc: 'optional: associated User ID'
        optional :code, type: String, desc: 'optional: issue code type (max 3 chars; see [goggles_db] Issue model for details)'
        optional :priority, type: Integer, desc: 'optional: request priority (0..3)'
        optional :status, type: Integer, desc: 'optional: request status (processable: 0..3, solved/rejected: 4..6)'
        optional :processable, type: Boolean, desc: 'optional: when +true+, returns only rows with \'processable\' status (0..3)'
        optional :done, type: Boolean, desc: 'optional: when +true+, returns only rows with status (4..6)'
        use :pagination
      end
      paginate
      get do
        reject_unless_authorized_admin(check_jwt_session)

        paginate(
          GogglesDb::Issue.where(filtering_hash_for(params, %w[user_id code priority status]))
                          .where(params[:processable] ? { status: [0, 1, 2, 3] } : nil)
                          .where(params[:done] ? { status: [4, 5, 6] } : nil)
        ).map(&:to_hash)
      end
    end
  end
end
