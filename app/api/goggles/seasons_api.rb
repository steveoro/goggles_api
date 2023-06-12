# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Season API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  class SeasonsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :season do
      # GET /api/:version/season/:id
      #
      # == Returns:
      # The Season instance matching the specified +id+ as JSON; an empty result when not found.
      # See GogglesDb::Season#to_json for structure details.
      #
      desc 'Season details'
      params do
        requires :id, type: Integer, desc: 'Season ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::Season.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/season/:id
      #
      # Allow direct update for most of the Season fields.
      # Requires CRUD grant on entity ('Season') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Season details'
      params do
        requires :id, type: Integer, desc: 'Season ID'
        optional :description, type: String, desc: 'verbose description'
        optional :begin_date, type: Date, desc: 'first day of the Season'
        optional :end_date, type: Date, desc: 'last day of the Season'
        optional :season_type_id, type: Integer, desc: 'associated SeasonType ID'
        optional :header_year, type: String, desc: 'referenced year(s) (format: YYYY or YYYY/YYYY+1)'
        optional :edition, type: Integer, desc: 'edition number'
        optional :edition_type_id, type: Integer, desc: 'associated EditionType ID'
        optional :timing_type_id, type: Integer, desc: 'associated TimingType ID'

        optional :individual_rank, type: Boolean, desc: 'true if individual rankings are supported'
        optional :badge_fee, type: Float, desc: 'base registration/badge fee (in local currency)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Season')

          season = GogglesDb::Season.find_by(id: params['id'])
          season&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/season
      #
      # Creates a new SeasonType given the specified parameters.
      # Requires Admin grants for the requesting user.
      #
      # == Required Params:
      # All Season params are required, with the exception of individual_rank & badge_fee.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new Season'
      params do
        requires :header_year, type: String, desc: 'referenced year(s) (format: YYYY or YYYY/YYYY+1)'
        requires :edition, type: Integer, desc: 'edition number'
        requires :season_type_id, type: Integer, desc: 'associated SeasonType ID'
        requires :timing_type_id, type: Integer, desc: 'associated TimingType ID'
        requires :edition_type_id, type: Integer, desc: 'associated EditionType ID'
        requires :description, type: String, desc: 'verbose description'
        requires :begin_date, type: Date, desc: 'first day of the Season'
        requires :end_date, type: Date, desc: 'last day of the Season'

        optional :id, type: Integer, desc: 'optional: override or force Season ID (must be unique)'
        optional :individual_rank, type: Boolean, desc: 'optional: true if individual rankings are supported'
        optional :badge_fee, type: Float, desc: 'optional: base registration/badge fee (in local currency)'
      end
      post do
        reject_unless_authorized_admin(check_jwt_session)

        new_row = GogglesDb::Season.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end
    end

    resource :seasons do
      # GET /api/:version/seasons
      #
      # Given some optional filtering parameters, returns the paginated list of seasons found.
      #
      # == Returns:
      # The list of Seasons for the specified filtering parameters as an array of JSON objects.
      # Returns only *exact* matches, no fuzzy or partial searches are done.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Season#to_json for structure details.
      #
      desc 'List Seasons'
      params do
        optional :begin_date, type: Date, desc: 'optional: first day of the Season'
        optional :end_date, type: Date, desc: 'optional: last day of the Season'
        optional :season_type_id, type: Integer, desc: 'optional: associated SeasonType ID'
        optional :header_year, type: String, desc: 'optional: referenced year(s) (format: YYYY or YYYY/YYYY+1)'
        use :pagination
      end
      # Enforcing 'max_per_page' will add the allowed range to the swagger docs and
      # cause Grape to return an error when an out-of-range value is specified.
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::Season.where(
          filtering_hash_for(
            params,
            %w[begin_date end_date season_type_id header_year]
          )
        ).order('seasons.id DESC').map(&:to_hash)
      end
    end
  end
end
