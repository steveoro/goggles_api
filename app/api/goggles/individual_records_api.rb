# frozen_string_literal: true

module Goggles
  # = Goggles API v3: IndividualRecord API Grape controller
  #
  # - version:  7-0.7.10
  # - author:   Steve A.
  # - build:    20240425
  #
  class IndividualRecordsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :individual_record do
      # GET /api/:version/individual_record/:id
      #
      # == Returns:
      # The IndividualRecord instance matching the specified +id+ as JSON.
      # See GogglesDb::IndividualRecord#to_json for structure details.
      #
      desc 'IndividualRecord details'
      params do
        requires :id, type: Integer, desc: 'IndividualRecord ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::IndividualRecord.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/individual_record/:id
      #
      # Allow direct update for all the IndividualRecord fields.
      # Requires CRUD grant on entity ('IndividualRecord') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update IndividualRecord details'
      params do
        requires :id, type: Integer, desc: 'IndividualRecord ID'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :federation_type_id, type: Integer, desc: 'optional: associated FederationType ID'
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MIR ID'
        optional :record_type_id, type: Integer, desc: 'optional: associated RecordType ID'

        optional :minutes, type: Integer, desc: 'optional: record time minutes'
        optional :seconds, type: Integer, desc: 'optional: record time seconds'
        optional :hundredths, type: Integer, desc: 'optional: record time hundredths of seconds'
        optional :team_record, type: Boolean, desc: 'optional: true if this is a team record (not necessarily a best result in the overall Championship)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'IndividualRecord')

          individual_record = GogglesDb::IndividualRecord.find_by(id: params['id'])
          individual_record&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/individual_record
      # Requires CRUD grant on entity ('IndividualRecord') for requesting user.
      #
      # Creates a new IndividualRecord given the specified parameters.
      #
      # == Required params:
      # - pool_type_id
      # - event_type_id
      # - category_type_id
      # - gender_type_id
      # - season_id
      # - federation_type_id
      # - team_id
      # - swimmer_id
      # - record_type_id
      #
      # Record timing defaults to zero.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Creates a new IndividualRecord'
      params do
        requires :pool_type_id, type: Integer, desc: 'associated PoolType ID'
        requires :event_type_id, type: Integer, desc: 'associated EventType ID'
        requires :category_type_id, type: Integer, desc: 'associated CategoryType ID'
        requires :gender_type_id, type: Integer, desc: 'associated GenderType ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        requires :swimmer_id, type: Integer, desc: 'associated Swimmer ID'
        requires :season_id, type: Integer, desc: 'associated Season ID'
        requires :federation_type_id, type: Integer, desc: 'associated FederationType ID'
        requires :record_type_id, type: Integer, desc: 'associated RecordType ID'

        optional :minutes, type: Integer, desc: 'optional: record time minutes'
        optional :seconds, type: Integer, desc: 'optional: record time seconds'
        optional :hundredths, type: Integer, desc: 'optional: record time hundredths of seconds'
        optional :team_record, type: Boolean, desc: 'optional: default: false; true if this is a team record (and not necessarily a championship record)'
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MIR ID'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'IndividualRecord')

        new_row = GogglesDb::IndividualRecord.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/individual_record/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('IndividualRecord') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a IndividualRecord'
      params do
        requires :id, type: Integer, desc: 'IndividualRecord ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'IndividualRecord')

          return unless GogglesDb::IndividualRecord.exists?(params['id'])

          GogglesDb::IndividualRecord.destroy(params['id']).destroyed?
        end
      end
    end

    resource :individual_records do
      # GET /api/:version/individual_records
      #
      # Given some optional filtering parameters, returns the paginated list of individual_records found.
      #
      # == Returns:
      # The list of IndividualRecords for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::IndividualRecord#to_json for structure details.
      #
      desc 'List IndividualRecords'
      params do
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :event_type_id, type: Integer, desc: 'optional: associated EventType ID'
        optional :category_type_id, type: Integer, desc: 'optional: associated CategoryType ID'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :federation_type_id, type: Integer, desc: 'optional: associated FederationType ID'
        optional :meeting_individual_result_id, type: Integer, desc: 'optional: associated MIR ID'
        optional :record_type_id, type: Integer, desc: 'optional: associated RecordType ID'
        optional :team_record, type: Boolean, desc: 'optional: true if this is a team record (not necessarily a best result in the overall Championship)'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::IndividualRecord.where(
            filtering_hash_for(
              params,
              %w[pool_type_id event_type_id category_type_id gender_type_id
                 team_id swimmer_id season_id federation_type_id
                 meeting_individual_result_id record_type_id team_record]
            )
          )
        ).map(&:to_hash)
      end
    end
  end
end
