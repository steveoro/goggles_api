# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Calendar API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  class CalendarsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :calendar do
      # GET /api/:version/calendar/:id
      #
      # == Returns:
      # The Calendar instance matching the specified +id+ as JSON.
      # See GogglesDb::Calendar#to_json for structure details.
      #
      desc 'Calendar details'
      params do
        requires :id, type: Integer, desc: 'Calendar ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::Calendar.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/calendar/:id
      #
      # Allows direct update for all the Calendar fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Calendar details'
      params do
        requires :id, type: Integer, desc: 'Calendar ID'
        optional :scheduled_date, type: String, desc: 'optional: schedule date or dates of the Meeting, usually separated by comma or dash (\'DD1-DD2\')'
        optional :month, type: String, desc: 'optional: month of the scheduled date of the Meeting, in 3-char format (\'MMM\')'
        optional :year, type: String, desc: 'optional: scheduled year of the Meeting (\'YYYY\')'

        optional :meeting_name, type: String, desc: 'optional: Meeting name'
        optional :meeting_place, type: String, desc: 'optional: Meeting place or city name'
        optional :manifest_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting manifest from the source URL (after publishing)'
        optional :startlist_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting starting list from the source URL (after publishing)'
        optional :results_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting result list from the source URL (after publishing)'

        optional :meeting_code, type: String, desc: 'optional: internal Meeting code-name for Goggles'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'

        optional :results_link, type: String,
                                desc: 'optional: direct URL to the Meeting results list (not always available; takes precedence over the base URL + code format)'
        optional :startlist_link, type: String,
                                  desc: 'optional: direct URL to the Meeting starting list (not always available; takes precedence over the base URL + code format)'
        optional :manifest_link, type: String,
                                 desc: 'optional: direct URL to the Meeting manifest (not always available; takes precedence over the base URL + code format)'

        optional :manifest, type: String, desc: 'optional: full manifest page text or full URL to manifest page (if public)'
        optional :name_import_text, type: String, desc: 'optional: text part containing the meeting name (as extracted from the manifest)'
        optional :organization_import_text, type: String, desc: 'optional: text part containing the organizing team name (as extracted from the manifest)'
        optional :place_import_text, type: String, desc: 'optional: text part containing the meeting place or city name (as extracted from the manifest)'
        optional :dates_import_text, type: String, desc: 'optional: text part containing the meeting dates (as extracted from the manifest)'
        optional :program_import_text, type: String, desc: 'optional: text part containing the meeting events or program (as extracted from the manifest)'

        optional :meeting_id, type: Integer, desc: 'optional: associated Meeting ID (usually set only after a successful importation)'
        optional :cancelled, type: Boolean, desc: 'optional: true if the Meeting has been cancelled'
        optional :read_only, type: Boolean, desc: 'optional: true to disable further editing by the automatic data-import procedure'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          calendar = GogglesDb::Calendar.find_by(id: params['id'])
          calendar&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/calendar
      #
      # Creates a new Calendar row given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - season_id: the associated Season ID
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new Calendar row'
      params do
        requires :season_id, type: Integer, desc: 'associated Season ID'

        optional :scheduled_date, type: String, desc: 'optional: schedule date or dates of the Meeting, usually separated by comma or dash (\'DD1-DD2\')'
        optional :month, type: String, desc: 'optional: month of the scheduled date of the Meeting, in 3-char format (\'MMM\')'
        optional :year, type: String, desc: 'optional: scheduled year of the Meeting (\'YYYY\')'

        optional :meeting_code, type: String,
                                desc: 'optional: internal Meeting code-name for Goggles (recurring meetings should have the same code to be easily identified)'
        optional :meeting_name, type: String, desc: 'optional: Meeting name'
        optional :meeting_place, type: String, desc: 'optional: Meeting place or city name'
        optional :manifest_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting manifest from the source URL (after publishing)'
        optional :startlist_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting starting list from the source URL (after publishing)'
        optional :results_code, type: String, desc: 'optional: parametric code used to retrieve the Meeting result list from the source URL (after publishing)'

        optional :results_link, type: String,
                                desc: 'optional: direct URL to the Meeting results list (not always available; takes precedence over the base URL + code format)'
        optional :startlist_link, type: String,
                                  desc: 'optional: direct URL to the Meeting starting list (not always available; takes precedence over the base URL + code format)'
        optional :manifest_link, type: String,
                                 desc: 'optional: direct URL to the Meeting manifest (not always available; takes precedence over the base URL + code format)'

        optional :manifest, type: String, desc: 'optional: full manifest page text or full URL to manifest page (if public)'
        optional :name_import_text, type: String, desc: 'optional: text part containing the meeting name (as extracted from the manifest)'
        optional :organization_import_text, type: String, desc: 'optional: text part containing the organizing team name (as extracted from the manifest)'
        optional :place_import_text, type: String, desc: 'optional: text part containing the meeting place or city name (as extracted from the manifest)'
        optional :dates_import_text, type: String, desc: 'optional: text part containing the meeting dates (as extracted from the manifest)'
        optional :program_import_text, type: String, desc: 'optional: text part containing the meeting events or program (as extracted from the manifest)'

        optional :meeting_id, type: Integer, desc: 'optional: associated Meeting ID (usually set only after a successful importation)'
        optional :cancelled, type: Boolean, desc: 'optional: true if the Meeting has been cancelled'
        optional :read_only, type: Boolean, desc: 'optional: true to disable further editing by the automatic data-import procedure'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::Calendar.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/calendar/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a Calendar'
      params do
        requires :id, type: Integer, desc: 'Calendar ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::Calendar.exists?(params['id'])

          GogglesDb::Calendar.destroy(params['id']).destroyed?
        end
      end
    end

    resource :calendars do
      # GET /api/:version/calendars
      #
      # Given some optional filtering parameters, returns the paginated list of calendars found.
      #
      # == Returns:
      # The list of Calendars for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Calendar#to_json for structure details.
      #
      desc 'List Calendars'
      params do
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::Calendar.where(
            filtering_hash_for(params, %w[season_id])
          ).order('calendars.id DESC')
        )
      end
    end
  end
end
