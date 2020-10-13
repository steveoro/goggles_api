# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Season API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201013
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
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Season.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/season/:id
      #
      # Allow direct update for most of the Season fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some Season details'
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

        optional :has_individual_rank, type: Boolean, desc: 'true if individual rankings are supported'
        optional :badge_fee, type: Float, desc: 'base registration/badge fee (in local currency)'
      end
      route_param :id do
        put do
          check_jwt_session

          season = GogglesDb::Season.find_by_id(params['id'])
          season&.update!(declared(params, include_missing: false))
        end
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
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::Season.where(
          filtering_hash_for(
            params,
            %w[begin_date end_date season_type_id header_year]
          )
        )
      end
    end
  end
end
