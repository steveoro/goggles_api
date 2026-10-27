# frozen_string_literal: true

module Goggles
  # = Goggles API v3: GoggleCup "team-manager" Grape controller
  #
  #   - version:  7-0.9.30
  #   - author:   Devin (for Steve A.)
  #   - build:    20261027
  #
  # Write path for Goggle Cup management shared by goggles_main (team managers
  # and admins over the web) and goggles_admin2 (localhost admins applying the
  # same edits remotely). All mutations run the domain services shipped inside
  # the goggles_db engine (GogglesDb::GogglesCup::*) so both frontends share a
  # single implementation.
  #
  # Authorization: each endpoint accepts a team_id/season_year pair (taken from
  # the cup row itself for row-level actions) and allows the request only when
  # the user is an admin OR manages an affiliation for that team inside that
  # championship year (ManagedAffiliation -> TeamAffiliation -> Season).
  #
  # Every mutation and the +sync+ endpoint return a +sync+ block containing the
  # cup row plus the provisioned TeamAffiliation and Badges for the latest
  # MASFIN season -- admin2 upserts that block into its local staging DB with
  # its "apply changes locally"/resync feature.
  class GoggleCupManageAPI < Grape::API # rubocop:disable Metrics/ClassLength
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    helpers do
      # Yields the 'Unauthorized' error unless +user+ is an admin or manages an
      # affiliation for +team_id+ in championship year +season_year+.
      def reject_unless_authorized_goggle_cup_manager(user, team_id, season_year)
        return if GogglesDb::GrantChecker.admin?(user)

        allowed = GogglesDb::ManagedAffiliation
                  .joins(team_affiliation: :season)
                  .where(user_id: user.id, team_affiliations: { team_id: team_id.to_i })
                  .merge(GogglesDb::Season.for_championship_year(season_year.to_i))
                  .exists?
        !allowed &&
          error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.invalid_user_grants'))
      end

      # The latest MASFIN season for the current championship year (nil when no
      # such season exists): the same target used by BadgeProvisioner.
      def goggle_cup_target_season
        year = GogglesDb::Season.current_championship_year(GogglesDb::SeasonType.mas_fin)
        GogglesDb::Season.for_season_type(GogglesDb::SeasonType.mas_fin)
                         .for_championship_year(year)
                         .first
      end

      # Builds the +sync+ block (cup + provisioned affiliation + badges for the
      # latest MASFIN season) used by admin2 to upsert its local copy.
      def goggle_cup_sync_payload(cup)
        season = goggle_cup_target_season
        affiliation = season && GogglesDb::TeamAffiliation.find_by(team_id: cup.team_id, season_id: season.id)
        badges = affiliation ? GogglesDb::Badge.where(team_affiliation_id: affiliation.id) : []
        {
          goggle_cup: cup.attributes,
          team_affiliation: affiliation&.attributes,
          badges: badges.map(&:attributes)
        }
      end

      # Finds the cup or yields a param error; also authorizes manager scope.
      def goggle_cup_managed_row(api_user, cup_id)
        cup = reject_unless_found(cup_id, GogglesDb::GoggleCup)
        reject_unless_authorized_goggle_cup_manager(api_user, cup.team_id, cup.season_year)
        cup
      end

      # Persists +cup+ and provisions missing badges for the enlisted swimmers
      # inside the same transaction; returns the provisioner report.
      def goggle_cup_save_and_provision(cup)
        report = nil
        GogglesDb::GoggleCup.transaction do
          unless cup.save
            error!(
              I18n.t('api.message.creation_failure'),
              422,
              'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(cup)
            )
          end
          report = GogglesDb::GogglesCup::BadgeProvisioner.new(cup).call
        end
        report
      end
    end

    resource :goggle_cup_manage do
      # GET /api/:version/goggle_cup_manage/swimmer_options
      #
      # Returns the selectable swimmer list (view rows + MASFIN badge rows) for
      # the given team & championship year.
      desc 'GoggleCup selectable swimmer options' do
        success code: 200, message: 'List of swimmer options'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :team_id, type: Integer, desc: 'Team ID (required)'
        requires :season_year, type: Integer, desc: 'Championship year (required)'
      end
      get :swimmer_options do
        api_user = check_jwt_session
        reject_unless_authorized_goggle_cup_manager(api_user, params['team_id'], params['season_year'])

        GogglesDb::GogglesCup::SwimmerOptionsQuery.new(
          team_id: params['team_id'], base_year: params['season_year']
        ).call
      end

      # GET /api/:version/goggle_cup_manage/smart_selection
      #
      # Returns the ids of the listed swimmers holding a badge for the given
      # secondary (filtering) team.
      desc 'GoggleCup smart swimmer selection for secondary team' do
        success code: 200, message: 'List of selected swimmer IDs'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :team_id, type: Integer, desc: 'Primary team ID (required)'
        requires :season_year, type: Integer, desc: 'Championship year (required)'
        optional :secondary_team_id, type: Integer, desc: 'Secondary/filtering team ID'
      end
      get :smart_selection do
        api_user = check_jwt_session
        reject_unless_authorized_goggle_cup_manager(api_user, params['team_id'], params['season_year'])

        selected_ids = GogglesDb::GogglesCup::SwimmerOptionsQuery.new(
          team_id: params['team_id'], base_year: params['season_year']
        ).smart_selected_ids_for(params['secondary_team_id'])
        { swimmer_ids: selected_ids }
      end

      # POST /api/:version/goggle_cup_manage
      #
      # Creates a new GoggleCup for a managed affiliation and provisions the
      # missing swimmer badges on the latest MASFIN season.
      #
      # == Required Params:
      # - team_id, season_year, description
      #
      # == Optional Params:
      # - name (defaults to description), end_date, swimmer_ids[]
      #
      # == Returns:
      #   { "cup": {...}, "badges_report": {...}, "sync": {...} }
      #
      desc 'Create a managed GoggleCup' do
        success code: 201, message: 'GoggleCup created'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [422, 'Unprocessable entity - Validation failure']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :team_id, type: Integer, desc: 'Associated Team ID (required)'
        requires :season_year, type: Integer, desc: 'Championship year (required)'
        requires :description, type: String, desc: 'GoggleCup description (required)'
        optional :name, type: String, desc: 'Recurring cup name (default: description)'
        optional :end_date, type: Date, desc: 'End date'
        optional :swimmer_ids, type: [Integer], desc: 'Enlisted swimmer IDs'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_goggle_cup_manager(api_user, params['team_id'], params['season_year'])

        cup = GogglesDb::GoggleCup.new(
          team_id: params['team_id'],
          season_year: params['season_year'],
          description: params['description'],
          name: params['name'].presence || params['description'].to_s.truncate(60, omission: ''),
          end_date: params['end_date'],
          swimmers_ids: Array(params['swimmer_ids']).compact_blank.map(&:to_i).join(',')
        )
        report = goggle_cup_save_and_provision(cup)

        { cup: cup.attributes, badges_report: report, sync: goggle_cup_sync_payload(cup) }
      end

      # PUT /api/:version/goggle_cup_manage/:id
      #
      # Updates a managed GoggleCup configuration (name, description, end_date,
      # enlisted swimmers). Clears the stored ranking_data when the swimmer
      # selection actually changes; provisions missing badges.
      desc 'Update a managed GoggleCup' do
        success code: 200, message: 'GoggleCup updated'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [422, 'Unprocessable entity - Validation failure']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
        optional :name, type: String, desc: 'Recurring cup name'
        optional :description, type: String, desc: 'GoggleCup description'
        optional :end_date, type: Date, desc: 'End date'
        optional :swimmer_ids, type: [Integer], desc: 'Enlisted swimmer IDs'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          previous_swimmer_ids = cup.swimmer_ids_array
          cup.assign_attributes(
            name: params['name'] || cup.name,
            description: params['description'] || cup.description,
            end_date: params.key?('end_date') ? params['end_date'] : cup.end_date
          )
          if params.key?('swimmer_ids')
            cup.swimmers_ids = Array(params['swimmer_ids']).compact_blank.map(&:to_i).join(',')
            cup.ranking_data = nil if cup.ranking_data.present? && cup.swimmer_ids_array.sort != previous_swimmer_ids.sort
          end

          report = goggle_cup_save_and_provision(cup)

          { cup: cup.attributes, badges_report: report, sync: goggle_cup_sync_payload(cup) }
        end
      end

      # POST /api/:version/goggle_cup_manage/:id/compute
      #
      # Computes the ranking for the cup's enlisted swimmers (or an explicit
      # override list) and persists it in ranking_data. The computation uses
      # the cup's season_year as the Scenic-views base year, reset afterwards.
      desc 'Compute and persist the GoggleCup ranking' do
        success code: 200, message: 'Ranking computed'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
        optional :swimmer_ids, type: [Integer], desc: 'Override swimmer IDs (default: cup selection)'
        optional :no_duplicated_events, type: Boolean, desc: 'Keep only the best row per event type'
      end
      route_param :id do
        post :compute do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          swimmer_ids = if params.key?('swimmer_ids')
                          Array(params['swimmer_ids']).compact_blank.map(&:to_i)
                        else
                          cup.swimmer_ids_array
                        end
          if swimmer_ids.present?
            GogglesDb::AbstractBestResult.with_base_year(cup.season_year)
            ranking = GogglesDb::GogglesCup::RankingCalculator.new(
              team_id: cup.team_id,
              swimmer_ids: swimmer_ids,
              no_duplicated_events: params['no_duplicated_events'] == true
            ).call
            serialized = GogglesDb::GoggleCupRanking::DataSerializer.new(
              cup: cup,
              ranking_data: ranking,
              no_duplicated_events: params['no_duplicated_events'] == true
            ).call
            cup.update!(ranking_data: serialized.to_json)
          end

          {
            cup: cup.attributes,
            ranking: GogglesDb::GoggleCupRanking::DataDeserializer.new(cup).call,
            sync: goggle_cup_sync_payload(cup)
          }
        ensure
          GogglesDb::AbstractBestResult.with_base_year(nil)
        end
      end

      # POST /api/:version/goggle_cup_manage/:id/clear_ranking
      #
      # Clears the stored ranking_data so the swimmer selection becomes
      # editable again.
      desc 'Clear the stored GoggleCup ranking' do
        success code: 200, message: 'Ranking cleared'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
      end
      route_param :id do
        post :clear_ranking do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          cup.update!(ranking_data: nil) if cup.ranking_data.present?
          { cup: cup.attributes, sync: goggle_cup_sync_payload(cup) }
        end
      end

      # POST /api/:version/goggle_cup_manage/:id/publish
      #
      # Marks the cup as the only published one for its (team, championship
      # year) affiliation, resetting the flag on sibling cups.
      desc 'Publish a GoggleCup' do
        success code: 200, message: 'GoggleCup published'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants'],
          [409, 'Conflict - another cup was published concurrently']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
      end
      route_param :id do
        post :publish do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          cup.publish!
          { cup: cup.attributes, sync: goggle_cup_sync_payload(cup) }
        rescue ActiveRecord::RecordNotUnique
          error!(I18n.t('api.message.invalid_parameter'), 409,
                 'X-Error-Detail' => 'another cup was already published for this affiliation')
        end
      end

      # POST /api/:version/goggle_cup_manage/:id/unpublish
      #
      # Clears the published flag on the cup.
      desc 'Unpublish a GoggleCup' do
        success code: 200, message: 'GoggleCup unpublished'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
      end
      route_param :id do
        post :unpublish do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          cup.unpublish!
          { cup: cup.attributes, sync: goggle_cup_sync_payload(cup) }
        end
      end

      # GET /api/:version/goggle_cup_manage/:id/sync
      #
      # Read-only sync payload (cup + provisioned affiliation + badges) used by
      # admin2 to overwrite its local copy of the row before editing.
      desc 'GoggleCup sync payload (row + provisioned badges)' do
        success code: 200, message: 'Sync payload'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :id, type: Integer, desc: 'GoggleCup ID (required)'
      end
      route_param :id do
        get :sync do
          api_user = check_jwt_session
          cup = goggle_cup_managed_row(api_user, params['id'])

          { cup: cup.attributes, sync: goggle_cup_sync_payload(cup) }
        end
      end
    end
  end
end
