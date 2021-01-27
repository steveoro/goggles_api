# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingEntry API Grape controller
  #
  #   - version:  7.062
  #   - author:   Steve A.
  #   - build:    20210119
  #
  class MeetingEntriesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_entry do
      # GET /api/:version/meeting_entry/:id
      #
      # == Returns:
      # The MeetingEntry instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingEntry#to_json for structure details.
      #
      desc 'MeetingEntry details'
      params do
        requires :id, type: Integer, desc: 'MeetingEntry ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::MeetingEntry.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/meeting_entry/:id
      #
      # Allow direct update for most of the MeetingEntry fields.
      # Requires CRUD grant on entity ('MeetingEntry') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingEntry details'
      params do
        requires :id, type: Integer, desc: 'MeetingEntry ID'
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :entry_time_type_id, type: Integer, desc: 'optional: associated EntryTimeType ID'
        optional :minutes, type: Integer, desc: 'optional: minutes for the registration entry timing'
        optional :seconds, type: Integer, desc: 'optional: seconds for the registration entry timing'
        optional :hundredths, type: Integer, desc: 'optional: hundredths of seconds for the registration entry timing'
        optional :no_time, type: Boolean, desc: 'optional: true for entries with an unspecified timing'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingEntry')

          meeting_entry = GogglesDb::MeetingEntry.find_by_id(params['id'])
          meeting_entry&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_entry
      # Requires CRUD grant on entity ('MeetingEntry') for requesting user.
      #
      # Creates a new MeetingEntry given the specified parameters.
      #
      # == Params:
      # - meeting_program_id (required)
      # - team_affiliation_id (required)
      # - team_id (required)
      # - swimmer_id
      # - badge_id
      # - entry_time_type_id
      # - minutes
      # - seconds
      # - hundredths => TODO: refactor this into a proper "hundredths" field name
      # - no_time (boolean): true for an unspecified entry timing
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingEntry'
      params do
        requires :meeting_program_id, type: Integer, desc: 'associated MeetingProgram ID'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :entry_time_type_id, type: Integer, desc: 'optional: associated EntryTimeType ID'
        optional :minutes, type: Integer, desc: 'optional: minutes for the registration entry time'
        optional :seconds, type: Integer, desc: 'optional: seconds for the registration entry time'
        optional :hundredths, type: Integer, desc: 'optional: hundredths of seconds for the registration entry time'
        optional :no_time, type: Boolean, desc: 'optional: true for entries with an unspecified timing'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'MeetingEntry')

        new_row = GogglesDb::MeetingEntry.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            500,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_entry/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('MeetingEntry') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingEntry'
      params do
        requires :id, type: Integer, desc: 'MeetingEntry ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingEntry')

          return unless GogglesDb::MeetingEntry.exists?(params['id'])

          GogglesDb::MeetingEntry.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_entries do
      # GET /api/:version/meeting_entries
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_entries found.
      #
      # == Returns:
      # The list of MeetingEntries for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingEntry#to_json for structure details.
      #
      desc 'List MeetingEntries'
      params do
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::MeetingEntry.where(
            filtering_hash_for(params, %w[meeting_program_id team_affiliation_id team_id swimmer_id badge_id])
          )
        )
      end
    end
  end
end
