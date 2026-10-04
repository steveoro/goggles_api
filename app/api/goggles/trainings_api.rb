# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Training API Grape controller
  #
  # Manages the "Creative trainings" photo gallery rows (GogglesDb::Training),
  # each one binding an uploaded picture to its metadata.
  #
  #   - version:  7-0.10.53
  #   - author:   Devin for Steve A.
  #
  class TrainingsAPI < Grape::API # rubocop:disable Metrics/ClassLength
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    helpers do
      # Returns the JSON payload for a Training row, enriched with the computed
      # attachment fields used by the gallery management UI:
      #
      # - picture_filename: original uploaded filename (stored in the AS blob, survives
      #   DB dump restores even when the backing file is missing)
      # - image_path:       permanent signed path to the full-size image, relative to the
      #                     API base URL (clients prepend their configured framework API URL)
      # - image_thumb_path: permanent signed path to a resized variant of the image
      # - image_missing:    true when the AS blob exists but its backing file is gone
      #                     from the storage area (=> re-upload needed)
      def training_payload(row)
        row.to_hash.merge(
          'picture_filename' => row.picture_filename,
          'image_path' => training_blob_path_for(row.picture),
          'image_thumb_path' => training_thumb_path_for(row),
          'image_missing' => row.picture.attached? && !row.picture_available?
        )
      end

      # Permanent signed blob-redirect path for an attachment proxy (nil when blank).
      def training_blob_path_for(attachable)
        return nil if attachable.blank? || !attachable.attached?

        Rails.application.routes.url_helpers.rails_blob_path(attachable.blob, only_path: true)
      end

      # Permanent signed representation-redirect path for a resized variant (nil when blank).
      def training_thumb_path_for(row)
        return nil unless row.picture.attached?

        variant = row.picture.variant(resize_to_limit: [320, 320])
        Rails.application.routes.url_helpers.rails_representation_path(variant, only_path: true)
      end

      # Attaches the multipart file param to the given row's :picture.
      # Yields a 401 error for invalid multipart params.
      def attach_picture_to!(row, file_param)
        filename = file_param&.fetch(:filename, nil)
        tempfile = file_param&.fetch(:tempfile, nil)
        content_type = file_param&.fetch(:type, nil)
        if filename.blank? || tempfile.blank?
          error!(I18n.t('api.message.invalid_parameter'), 401,
                 'X-Error-Detail' => ':image multipart data invalid')
        end

        old_blob = row.picture.blob if row.picture.attached?
        row.picture.attach(io: tempfile, filename:, content_type:)
        old_blob
      end

      # Parses the training_date param (ISO date or datetime); yields a 401 error when unparseable.
      def parse_training_date!(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        error!(I18n.t('api.message.invalid_parameter'), 401,
               'X-Error-Detail' => ':training_date not a valid ISO date/datetime')
      end
    end
    #-- -----------------------------------------------------------------------
    #++

    resource :training do
      # GET /api/:version/training/:id
      #
      # == Returns:
      # The Training instance matching the specified +id+ as JSON
      # (enriched with picture_filename, image_path, image_thumb_path & image_missing).
      #
      desc 'Training details' do
        success Goggles::Entities::TrainingEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'Training ID'
      end
      route_param :id do
        get do
          check_jwt_session

          row = GogglesDb::Training.find_by(id: params['id'])
          training_payload(row) if row.present?
        end
      end

      # POST /api/:version/training
      #
      # Creates a new Training row with its attached picture (multipart upload).
      # The file is stored in the shared storage area by ActiveStorage; the original
      # filename is kept in the AS blob so the picture can be matched & re-uploaded
      # after a DB restore.
      #
      # Requires Admin grants for the requesting user.
      #
      # == Params:
      # - image: (image file, required) the uploaded picture (jpeg/png/webp/gif)
      # - training_by: (string, required) who ran the training
      # - created_by: (string, required) who created the picture/workout
      # - training_date: (string, required) ISO date or datetime for the training session
      # - swimmer_id: (integer, optional) associated Swimmer ID for the 'created by' link
      # - description: (string, optional) text content of the training
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the new row ID:
      #
      #    { "msg": "OK", "new": { "id": <new_row_id> } }
      #
      desc 'Create new Training with attached picture' do
        success code: 201, message: 'Training created'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT, grants or multipart parameters'],
          [422, 'Unprocessable entity - Validation failure']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :image, type: File, desc: 'uploaded picture file (jpeg/png/webp/gif)'
        requires :training_by, type: String, desc: 'who ran the training'
        requires :created_by, type: String, desc: 'who created the picture/workout'
        requires :training_date, type: String, desc: 'training session date (ISO format)'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :description, type: String, desc: 'optional: text content of the training'
      end
      post do
        admin_user = check_jwt_session
        reject_unless_authorized_admin(admin_user)

        swimmer_id = params['swimmer_id'].to_i.positive? ? params['swimmer_id'] : nil
        reject_unless_found(swimmer_id, GogglesDb::Swimmer) if swimmer_id.present?

        new_row = GogglesDb::Training.new(
          training_by: params['training_by'],
          created_by: params['created_by'],
          training_date: parse_training_date!(params['training_date']),
          swimmer_id:,
          description: params['description']
        )
        attach_picture_to!(new_row, params[:image])

        unless new_row.save
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: { id: new_row.id } }
      end

      # PUT /api/:version/training/:id
      #
      # Updates an existing Training row. All fields are optional; the +image+
      # multipart file, when present, replaces the attached picture (use it to
      # re-upload a missing image after a storage restore).
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Update a Training row (and optionally re-attach its picture)' do
        success code: 200, message: 'Training updated'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [422, 'Unprocessable entity - Validation failure']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'Training ID'
        optional :image, type: File, desc: 'optional: new picture file replacing the current one'
        optional :training_by, type: String, desc: 'optional: who ran the training'
        optional :created_by, type: String, desc: 'optional: who created the picture/workout'
        optional :training_date, type: String, desc: 'optional: training session date (ISO format)'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID (pass empty to clear)'
        optional :description, type: String, desc: 'optional: text content of the training'
      end
      route_param :id do
        put do
          admin_user = check_jwt_session
          reject_unless_authorized_admin(admin_user)

          row = GogglesDb::Training.find_by(id: params['id'])
          return unless row

          attributes = {}
          %w[training_by created_by description].each do |key|
            attributes[key] = params[key] if params.key?(key)
          end
          attributes['training_date'] = parse_training_date!(params['training_date']) if params['training_date'].present?
          if params.key?('swimmer_id')
            attributes['swimmer_id'] = params['swimmer_id'].to_i.positive? ? params['swimmer_id'] : nil
            reject_unless_found(attributes['swimmer_id'], GogglesDb::Swimmer) if attributes['swimmer_id'].present?
          end

          replaced_blob = attach_picture_to!(row, params[:image]) if params[:image].present?
          if row.update(attributes)
            replaced_blob&.purge
            training_payload(row)
          else
            error!(
              I18n.t('api.message.creation_failure'),
              422,
              'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(row)
            )
          end
        end
      end

      # DELETE /api/:version/training/:id
      #
      # Deletes a Training row together with its attached picture blob & file.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a Training and its picture' do
        success code: 200, message: 'Training deleted'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'Training ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          row = GogglesDb::Training.find_by(id: params['id'])
          return unless row

          row.picture.purge if row.picture.attached?
          row.destroy.destroyed?
        end
      end
    end
    #-- -----------------------------------------------------------------------
    #++

    resource :trainings do
      # GET /api/:version/trainings
      #
      # Returns the paginated list of all "Creative trainings" rows having an
      # attached picture, sorted by training_date DESC, enriched with
      # picture_filename, image_path, image_thumb_path & image_missing.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      desc 'List Creative trainings (with attached pictures)' do
        is_array true
        success Goggles::Entities::TrainingEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        optional :training_by, type: String, desc: 'optional: exact match'
        optional :created_by, type: String, desc: 'optional: exact match'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :date, type: String, desc: 'optional: training_date in ISO format (YYYY-MM-DD)'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        results = GogglesDb::Training.with_picture
                                     .where(filtering_hash_for(params, %w[training_by created_by swimmer_id]))
                                     .where(filtering_for_single_parameter('DATE(training_date) = ?', params, 'date'))
                                     .by_date(:desc)

        paginate(results).map { |row| training_payload(row) }
      end
    end
  end
end
