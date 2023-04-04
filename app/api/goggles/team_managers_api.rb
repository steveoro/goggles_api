# frozen_string_literal: true

module Goggles
  # = Goggles API v3: ManagedAffiliation (team/manager) API
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  # Implements full CRUD interface for ManagedAffiliation.
  #
  # Note: all the User/managers associated to a TeamAffiliation are already included in the
  #       response of 'GET /team_affiliation/:id'.
  #
  class TeamManagersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :team_manager do
      # GET /api/:version/team_manager/:id
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The ManagedAffiliation instance matching the specified +id+ as JSON.
      # See GogglesDb::ManagedAffiliation#to_json for structure details.
      #
      desc 'ManagedAffiliation details'
      params do
        requires :id, type: Integer, desc: 'ManagedAffiliation ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          reject_unless_authorized_admin(check_jwt_session)
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::ManagedAffiliation.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/team_manager/:id
      #
      # Allow direct update of a ManagedAffiliation row.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update ManagedAffiliation details'
      params do
        requires :id, type: Integer, desc: 'ManagedAffiliation ID'
        optional :user_id, type: Integer, desc: 'optional: associated User ID (Team Manager)'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          team_manager = GogglesDb::ManagedAffiliation.find_by(id: params['id'])
          team_manager&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/team_manager
      # (ADMIN only)
      #
      # Creates a new ManagedAffiliation given the specified parameters.
      #
      # == Params:
      # - user_id: associated User as new Manager
      # - team_affiliation_id: associated TeamAffiliation
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new ManagedAffiliation'
      params do
        requires :user_id, type: Integer, desc: 'associated User ID (new Manager)'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)

        new_row = GogglesDb::ManagedAffiliation.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/team_manager/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a ManagedAffiliation'
      params do
        requires :id, type: Integer, desc: 'ManagedAffiliation ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::ManagedAffiliation.exists?(params['id'])

          GogglesDb::ManagedAffiliation.destroy(params['id']).destroyed?
        end
      end
    end

    resource :team_managers do
      # GET /api/:version/team_managers
      #
      # Given some optional filtering parameters, returns the paginated list of team_managers found.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The list of ManagedAffiliations for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::ManagedAffiliation#to_json for structure details.
      #
      desc 'List ManagedAffiliations'
      params do
        optional :user_id, type: Integer, desc: 'optional: associated User (Manager) ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'

        optional :manager_name, type: String, desc: 'optional: filter by user/manager name (LIKE supported)'
        optional :team_name, type: String, desc: 'optional: filter by team name (LIKE supported)'
        optional :season_description, type: String, desc: 'optional: filter by season description (LIKE supported)'
        use :pagination
      end
      paginate
      get do
        reject_unless_authorized_admin(check_jwt_session)

        # Use explicit table mappings in like condition due to joins:
        joined_tables_mappings = {
          'manager_name' => 'users.name',
          'team_name' => 'teams.name',
          'season_description' => 'seasons.description'
        }.keep_if { |field_name, _name_in_table| params.key?(field_name) }
                                 .map { |_field_name, name_in_table| "(#{name_in_table} LIKE ?)" }
                                 .join(' AND ')

        field_values = params.dup
                             .keep_if { |key, _v| %w[manager_name team_name season_description].include?(key) }
                             .values.map { |value| "%#{value}%" }
        like_condition = ActiveRecord::Base.sanitize_sql_array([joined_tables_mappings, field_values].flatten) unless field_values.empty?
        # Alias params so that these work with filtering_hash_for():
        params['teams.id'] = params['team_id']
        params['seasons.id'] = params['season_id']

        results = GogglesDb::ManagedAffiliation.joins(:season, :team, :manager)
                                               .includes(:season, :team, :manager)
                                               .where(
                                                 filtering_hash_for(params, %w[user_id team_affiliation_id seasons.id teams.id])
                                               )
                                               .where(
                                                 like_condition
                                               )
                                               .order('managed_affiliations.id DESC')
        paginate(results)
      end
    end
  end
end
