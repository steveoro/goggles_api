# frozen_string_literal: true

module Goggles
  # = Goggles API v3: UserWorkshop API Grape controller
  #
  #   - version:  7-0.3.39
  #   - author:   Steve A.
  #   - build:    20211115
  #
  class UserWorkshopsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :user_workshop do
      # GET /api/:version/user_workshop/:id
      #
      # == Returns:
      # The UserWorkshop instance matching the specified +id+ as JSON.
      # See GogglesDb::UserWorkshop#to_json for structure details.
      #
      desc 'UserWorkshop details'
      params do
        requires :id, type: Integer, desc: 'UserWorkshop ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::UserWorkshop.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/user_workshop/:id
      #
      # Allow direct update for most of the UserWorkshop fields.
      # Requires CRUD grant on entity ('UserWorkshop') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update UserWorkshop details'
      params do
        requires :id, type: Integer, desc: 'User Workshop ID'
        optional :code, type: String, desc: 'optional: Workshop code-name (recurring workshops should have the same code to be easily identified)'
        optional :header_date, type: String, desc: 'optional: header (main) date for the UserWorkshop in ISO format (\'YYYY-MM-DD\')'
        optional :header_year, type: String, desc: 'optional: header (main) year for the UserWorkshop (\'YYYY\')'
        optional :description, type: String, desc: 'displayed Workshop description'
        optional :notes, type: String, desc: 'optional: additional notes'
        optional :edition, type: Integer, desc: 'optional: Edition number'
        optional :edition_type_id, type: Integer, desc: 'optional: EditionType ID'
        optional :timing_type_id, type: Integer, desc: 'optional: TimingType ID'

        optional :user_id, type: Integer, desc: 'optional: User registering this information'
        optional :team_id, type: Integer, desc: 'optional: Organizing Home Team ID or default Team ID for this Workshop'
        optional :season_id, type: Integer, desc: 'optional: Season ID for the Workshop (Admin only)'
        optional :swimming_pool_id, type: Integer, desc: 'optional: Swimming Pool ID (venue or location) for this Workshop'

        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :off_season, type: Boolean, desc: 'optional: true if the UserWorkshop does not concur in the overall scoring of its Season'
        optional :confirmed, type: Boolean, desc: 'optional: true if the Workshop has been confirmed'
        optional :cancelled, type: Boolean, desc: 'optional: true if the Workshop has been cancelled'
        optional :pb_acquired, type: Boolean, desc: 'optional: true if athletes\' personal-best timings and scores have already been computed'
        optional :read_only, type: Boolean, desc: 'optional: true to disable further editing by automatic data-import procedure (Admin only)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'UserWorkshop')

          result = GogglesDb::UserWorkshop.find_by(id: params['id'])
          # Reject altering admin-only attributes unless user has admin grants:
          params.delete_if { |key, _value| %w[read_only season_id].include?(key) } unless GogglesDb::GrantChecker.admin?(api_user)
          # Don't do anything if we're left with no editing parameters:
          result&.update!(declared(params, include_missing: false)) unless params.keys.size == 1
        end
      end

      # POST /api/:version/user_workshop
      #
      # Creates a new UserWorkshop given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # - code
      # - header_date
      # - header_year
      # - edition_type_id
      # - user_id
      # - team_id
      # - season_id
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new UserWorkshop'
      params do
        requires :code, type: String, desc: 'Workshop code-name (recurring workshops should have the same code to be easily identified)'
        requires :header_date, type: String, desc: 'header (main) date for the UserWorkshop in ISO format (\'YYYY-MM-DD\')'
        requires :header_year, type: String, desc: 'header (main) year for the UserWorkshop (\'YYYY\')'
        requires :edition_type_id, type: Integer, desc: 'EditionType ID'
        requires :timing_type_id, type: Integer, desc: 'TimingType ID'
        requires :user_id, type: Integer, desc: 'User registering this information'
        requires :team_id, type: Integer, desc: 'Organizing Team ID or default Team ID for this Workshop'
        requires :season_id, type: Integer, desc: 'Season ID for the Workshop (Admin only)'

        optional :swimming_pool_id, type: Integer, desc: 'optional: Swimming Pool ID (venue or location) for this Workshop'
        optional :description, type: String, desc: 'optional: displayed Workshop description'
        optional :notes, type: String, desc: 'optional: additional notes'
        optional :edition, type: Integer, desc: 'optional: Edition number'
        optional :autofilled, type: Boolean, desc: 'optional: true if the fields have been filled-in by the data-import procedure (may need revision)'
        optional :off_season, type: Boolean, desc: 'optional: true if the UserWorkshop does not concur in the overall scoring of its Season'
        optional :confirmed, type: Boolean, desc: 'optional: true if the Workshop has been confirmed'
        optional :cancelled, type: Boolean, desc: 'optional: true if the Workshop has been cancelled'
        optional :pb_acquired, type: Boolean, desc: 'optional: true if athletes\' personal-best timings and scores have already been computed'
        optional :read_only, type: Boolean, desc: 'optional: true to disable further editing by automatic data-import procedure (Admin only)'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::UserWorkshop.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/user_workshop/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a UserWorkshop'
      params do
        requires :id, type: Integer, desc: 'UserWorkshop ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::UserWorkshop.exists?(params['id'])

          GogglesDb::UserWorkshop.destroy(params['id']).destroyed?
        end
      end
    end

    resource :user_workshops do
      # GET /api/:version/user_workshops
      #
      # Given some optional filtering parameters, returns the paginated list of user_workshops found.
      #
      # *Supports the bespoke "Select2 option" output format*
      #
      # == Returns:
      # The list of UserWorkshops for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::UserWorkshop#to_json for structure details.
      #
      desc 'List UserWorkshops'
      params do
        optional :name, type: String, desc: 'optional: generic FULLTEXT search on description & code fields'
        optional :user_id, type: Integer, desc: 'optional: User registering this information'
        optional :team_id, type: Integer, desc: 'optional: Organizing Team ID or default Team ID for this Workshop'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :date, type: String, desc: 'optional: header_date or scheduled_date in ISO format (YYYY-MM-DD)'
        optional :header_year, type: String, desc: 'optional: header (main) year for the UserWorkshop (\'YYYY\')'
        optional :select2_format, type: Boolean, desc: 'optional: true to enable the simplified (id+text) Select2 output format'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        results = filtering_fulltext_search_for(GogglesDb::UserWorkshop, params['name'])
                  .where(filtering_hash_for(params, %w[user_id team_id season_id]))
                  .where(filtering_for_single_parameter('header_date = ?', params, 'date'))
                  .where(filtering_like_for(params, %w[header_year]))
                  .distinct

        if params['select2_format'] == true
          select2_custom_format(results, ->(row) { "#{row.description} (#{row.code} - #{row.header_date})" })
        else
          paginate(results)
        end
      end
    end
  end
end
