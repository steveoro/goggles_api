# frozen_string_literal: true

module Goggles
  # = Goggles API v3: ImportQueue API Grape controller
  #
  #   - version:  7-0.4.05
  #   - author:   Steve A.
  #   - build:    20220825
  #
  # Implements full CRUD interface for ImportQueue.
  #
  class ImportQueuesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :import_queue do
      # GET /api/:version/import_queue/:id
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The ImportQueue instance matching the specified +id+ as JSON.
      # See GogglesDb::ImportQueue#to_json for structure details.
      #
      desc 'ImportQueue details'
      params do
        requires :id, type: Integer, desc: 'ImportQueue ID'
      end
      route_param :id do
        get do
          reject_unless_authorized_admin(check_jwt_session)

          GogglesDb::ImportQueue.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/import_queue/:id
      #
      # Allow direct update for most of the ImportQueue fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update ImportQueue details'
      params do
        requires :id, type: Integer, desc: 'ImportQueue ID'
        optional :user_id, type: Integer, desc: 'optional: associated User ID'
        optional :process_runs, type: Integer, desc: 'optional: current processed depth'
        optional :request_data, type: String, desc: 'optional: parsable JSON containing the requested entities and their current state'
        optional :solved_data, type: String, desc: 'optional: parsable JSON containing all associated entities with their IDs that have been \"solved\"'
        optional :done, type: Boolean, desc: 'optional: true if this request is deletable (both processed & solved completely)'
        optional :uid, type: String, desc: 'optional: queue UID'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          import_queue = GogglesDb::ImportQueue.find_by(id: params['id'])
          import_queue&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/import_queue
      #
      # Creates a new ImportQueue given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Params:
      # - user_id (required)
      # - request_data (required)
      # - solved_data
      # - done
      # - uid
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new ImportQueue'
      params do
        requires :user_id, type: Integer, desc: 'associated User ID'
        requires :request_data, type: String, desc: 'parsable JSON containing the requested entities and thei current state'
        optional :solved_data, type: String, desc: 'optional: parsable JSON containing all associated entities with their IDs that have been \"solved\"'
        optional :done, type: Boolean, desc: 'optional: true if this request is deletable (both processed & solved completely)'
        optional :uid, type: String, desc: 'optional: queue UID'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::ImportQueue.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # POST /api/:version/import_queue/batch_sql
      #
      # Creates a new ImportQueue storing an executable SQL batch file.
      #
      # The payload will be processed and executed by the same service handling the
      # "standard" micro-transaction ImportQueues, with the difference that in
      # this case the <tt>batch_sql</tt> flag will be set and the payload file will be
      # stored for delayed execution in the context of the Main app.
      #
      # Requires Admin grants for the requesting user.
      #
      # == Params:
      # - data_file: (text file, required) the uploaded file (Rack::Multipart::UploadedFile)
      #              allegedly containing only valid SQL batch statement(s), possibly all wrapped in
      #              a single transaction).
      #
      # == Note:
      # The actual SQL parsing will be done only by the consumer service job running
      # inside the Main app; this endpoint won't be able to signal in advance if the file
      # is error free or not.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and just the ID of the newly created row:
      #
      #    { "msg": "OK", "new": { id: <new_row_id> } }
      #
      desc 'Creates a new ImportQueue storing an executable SQL batch file'
      params do
        requires :data_file, type: File, desc: 'a valid SQL batch file (supporting multi statements)'
      end
      post :batch_sql do
        admin_user = check_jwt_session
        reject_unless_authorized_admin(admin_user)

        # File/Multipart params in Grape have 3 sub-attributes:
        # - :filename (string) => actual file name
        # - :tempfile (File)   => link to the IO object generated with the multipart REST POST
        # - :type (string)     => file type
        filename = params[:data_file]&.fetch(:filename, nil)
        tempfile = params[:data_file]&.fetch(:tempfile, nil)
        error!(I18n.t('api.message.invalid_parameter'), 401, 'X-Error-Detail' => ':data_file multipart data invalid') if filename.blank? || tempfile.blank?

        new_row = GogglesDb::ImportQueue.new(batch_sql: true, user_id: admin_user.id,
                                             request_data: '{}', solved_data: '{}')
        new_row.data_file.attach(filename:, io: tempfile)
        unless new_row.save
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: { id: new_row.id } }
      end

      # DELETE /api/:version/import_queue/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a ImportQueue'
      params do
        requires :id, type: Integer, desc: 'ImportQueue ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::ImportQueue.exists?(params['id'])

          GogglesDb::ImportQueue.destroy(params['id']).destroyed?
        end
      end
    end

    resource :import_queues do
      # GET /api/:version/import_queues
      #
      # Given some optional filtering parameters, returns the paginated list of import_queues found.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The list of ImportQueues for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::ImportQueue#to_json for structure details.
      #
      desc 'List ImportQueues'
      params do
        optional :user_id, type: Integer, desc: 'optional: associated User ID'
        optional :uid, type: String, desc: 'optional: queue UID'
        optional :process_runs, type: Integer, desc: 'optional: current processed depth'
        optional :requested_depth, type: Integer, desc: 'optional: current requested depth'
        optional :solvable_depth, type: Integer, desc: 'optional: current solvable depth'
        optional :done, type: Boolean, desc: 'optional: true if this request is deletable (both processed & solved completely)'
        use :pagination
      end
      paginate
      get do
        reject_unless_authorized_admin(check_jwt_session)

        paginate(
          GogglesDb::ImportQueue.where(
            filtering_hash_for(params, %w[user_id uid process_runs requested_depth solvable_depth done])
          )
        ).map(&:to_hash)
      end
    end
  end
end
