# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Meeting API Grape controller
  #
  #   - version:  7.051
  #   - author:   Steve A.
  #   - build:    20201218
  #
  class MeetingsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :meeting do
      # GET /api/:version/meeting/:id
      #
      # == Returns:
      # The Meeting instance matching the specified +id+ as JSON; an empty result when not found.
      # See GogglesDb::Meeting#to_json for structure details.
      #
      desc 'Meeting details'
      params do
        requires :id, type: Integer, desc: 'Meeting ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Meeting.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/meeting/:id
      #
      # Allows direct updates for Meeting fields.
      # Requires CRUD grant on entity ('Meeting') for the requesting user.
      # Generic admin grants are required for `read_only` & `season_id` fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Meeting details'
      params do
        requires :id, type: Integer, desc: 'Meeting ID'
        optional :code, type: String, desc: 'optional: Meeting code-name (recurring meetings should have the same code to be easily identified)'
        optional :header_date, type: String, desc: 'optional: header (main) date for the Meeting in ISO format (\'YYYY-MM-DD\')'
        optional :header_year, type: String, desc: 'optional: header (main) year for the Meeting (\'YYYY\')'
        optional :description, type: String, desc: 'displayed Meeting description'
        optional :entry_deadline, type: String, desc: 'optional: entry deadline for registration, in ISO format (\'YYYY-MM-DD\')'
        optional :warm_up_pool, type: Boolean, desc: 'optional: true if a warm-up pool is available during the Meeting'
        optional :allows_under25, type: Boolean, desc: 'optional: true if under-25 can compete'
        optional :reference_phone, type: String, desc: 'optional: contact or reference phone'
        optional :reference_e_mail, type: String, desc: 'optional: contact or reference e-mail'
        optional :reference_name, type: String, desc: 'optional: contact or reference name'
        optional :max_individual_events, type: Integer, desc: 'optional: max number of indiv. events x session (x athlete)'
        optional :meeting_fee, type: Integer, desc: 'optional: main enrollment/registration cost (converted to Euros, if needed)'
        optional :event_fee, type: Integer, desc: 'optional: individual event cost (converted to Euros, if needed)'
        optional :relay_fee, type: Integer, desc: 'optional: relay event cost (converted to Euros, if needed)'
        optional :notes, type: String, desc: 'optional: additional notes'

        optional :home_team_id, type: Integer, desc: 'optional: Team ID of the organizing Team behind this Meeting'
        optional :edition, type: Integer, desc: 'optional: Edition number'
        optional :edition_type_id, type: Integer, desc: 'optional: EditionType ID'
        optional :timing_type_id, type: Integer, desc: 'optional: TimingType ID'
        optional :individual_score_computation_type_id, type: Integer, desc: 'optional: IndividualScoreComputationType ID'
        optional :relay_score_computation_type_id, type: Integer, desc: 'optional: RelayScoreComputationType ID'
        optional :team_score_computation_type_id, type: Integer, desc: 'optional: TeamScoreComputationType ID'
        optional :meeting_score_computation_type_id, type: Integer, desc: 'optional: MeetingScoreComputationType ID'

        optional :manifest_body, type: String, desc: 'optional: Meeting Manifest body (either in text or html format, stripped of styles & scripts)'
        optional :manifest, type: Boolean, desc: 'optional: true if the Meeting manifest is available or published and can be acquired'

        optional :confirmed, type: Boolean, desc: 'optional: true if the Meeting has been confirmed'
        optional :cancelled, type: Boolean, desc: 'optional: true if the Meeting has been cancelled'
        optional :startlist, type: Boolean, desc: 'optional: true if the starting list has been published (and can be acquired)'
        optional :results_acquired, type: Boolean, desc: 'optional: true if the results have been already acquired'
        optional :off_season, type: Boolean, desc: 'optional: true if the Meeting does not concur in the overall scoring of its Season'
        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :tweeted, type: Boolean, desc: 'optional: true if the Meeting result link has been already tweeted'
        optional :posted, type: Boolean, desc: 'optional: true if the Meeting result link has been already posted on other Social Media'
        optional :pb_acquired, type: Boolean, desc: 'optional: true if athletes\' personal-best timings and scores have already been computed'

        optional :season_id, type: Integer, desc: 'optional: Season ID for the Meeting (Admin only)'
        optional :read_only, type: Boolean, desc: 'optional: true to disable further editing by automatic data-import procedure (Admin only)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Meeting')

          result = GogglesDb::Meeting.find_by_id(params['id'])
          # Reject altering admin-only attributes unless user has admin grants:
          params.delete_if { |key, _value| %w[read_only season_id].include?(key) } unless GogglesDb::GrantChecker.admin?(api_user)
          # Don't do anything if we're left with no editing parameters:
          result&.update!(declared(params, include_missing: false)) unless params.keys.size == 1
        end
      end
    end

    resource :meetings do
      # GET /api/:version/meetings
      #
      # Given some optional filtering parameters, returns the paginated list of meetings found.
      #
      # == Returns:
      # The list of Meetings for the specified filtering parameters as an array of JSON objects.
      # Supports a FULLTEXT search by the generic 'name' parameter on the 'description' & 'code' fields.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Meeting#to_json for structure details.
      #
      desc 'List Meetings'
      params do
        optional :name, type: String, desc: 'optional: generic FULLTEXT search on description & code fields'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :pool_type_id, type: Integer, desc: 'optional: associated meeting_sessions.pool_type ID'
        optional :date, type: String, desc: 'optional: header_date or scheduled_date in ISO format (YYYY-MM-DD)'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        # .where(filtering_like_for_single_parameter('meetings.description LIKE ?', params, 'description'))
        paginate(
          filtering_fulltext_search_for(GogglesDb::Meeting, params['name'])
            .joins(meeting_sessions: :swimming_pool).includes(meeting_sessions: :swimming_pool)
              .where(filtering_hash_for(params, ['season_id']))
              .where(filtering_for_single_parameter('(header_date = ?) OR (meeting_sessions.scheduled_date = ?)', params, 'date'))
              .where(filtering_for_single_parameter('swimming_pools.pool_type_id = ?', params, 'pool_type_id'))
              .distinct
        )
      end
    end
  end
end
