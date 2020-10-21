# frozen_string_literal: true

module Goggles
  # = Goggles API v3: TeamAffiliation API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class TeamAffiliationsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :team_affiliation do
      # GET /api/:version/team_affiliation/:id
      #
      # == Returns:
      # The TeamAffiliation instance matching the specified +id+ as JSON.
      # See GogglesDb::TeamAffiliation#to_json for structure details.
      #
      desc 'TeamAffiliation details'
      params do
        requires :id, type: Integer, desc: 'TeamAffiliation ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::TeamAffiliation.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/team_affiliation/:id
      #
      # Allow direct update for most of the TeamAffiliation fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some TeamAffiliation details'
      params do
        requires :id, type: Integer, desc: 'TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'associated Team ID'
        optional :season_id, type: Integer, desc: 'associated Season ID'
        optional :name, type: String, desc: 'name as it appears in the registration rooster for the Championship Season'
        optional :number, type: String, desc: 'enrollment or registration badge number'
        optional :must_calculate_goggle_cup, type: Boolean, desc: 'true when the customized GoggleCup has to be computed'
      end
      route_param :id do
        put do
          check_jwt_session

          team_affiliation = GogglesDb::TeamAffiliation.find_by_id(params['id'])
          team_affiliation&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :team_affiliations do
      # GET /api/:version/team_affiliations
      #
      # Given some optional filtering parameters, returns the paginated list of team_affiliations found.
      #
      # == Returns:
      # The list of TeamAffiliations for the specified filtering parameters as an array of JSON objects.
      # Returns exact matches for most of the parameters, supports partial matches just for the text name,
      # but no fuzzy searches are performed here. (Use dedicated /search endpoints for that.)
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::TeamAffiliation#to_json for structure details.
      #
      desc 'List TeamAffiliations'
      params do
        optional :team_id, type: Integer, desc: 'optional: Team ID'
        optional :season_id, type: Integer, desc: 'optional: Season ID'
        optional :name, type: String, desc: 'optional: enrollment name'
        optional :number, type: String, desc: 'optional: enrollment number'
        optional :must_calculate_goggle_cup, type: Boolean, desc: 'optional: true for GoggleCup affiliations'
        use :pagination
      end
      # Enforcing 'max_per_page' will add the allowed range to the swagger docs and
      # cause Grape to return an error when an out-of-range value is specified.
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::TeamAffiliation.where(
          filtering_hash_for(params, %w[team_id season_id number must_calculate_goggle_cup])
        ).where(
          filtering_like_for(params, %w[name])
        )
      end
    end
  end
end
