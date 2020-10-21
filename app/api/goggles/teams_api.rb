# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Team API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class TeamsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :team do
      # GET /api/:version/team/:id
      #
      # == Returns:
      # The Team instance matching the specified +id+ as JSON.
      # See GogglesDb::Team#to_json for structure details.
      #
      desc 'Team details'
      params do
        requires :id, type: Integer, desc: 'Team ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Team.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/team/:id
      #
      # Allow direct update for most of the Team fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some Team details'
      params do
        requires :id, type: Integer, desc: 'Team ID'
        optional :name, type: String, desc: 'name of the Team' # (This field was normally intended as read-only)
        optional :editable_name, type: String, desc: 'name of the Team, as edited by the Team Manager'
        optional :city_id, type: Integer, desc: 'associated City ID'
        optional :address, type: String, desc: 'Team HQ address'
        optional :zip, type: String, desc: 'Team HQ zip code, if available'
        optional :phone_mobile, type: String, desc: 'HQ mobile or secondary phone'
        optional :phone_number, type: String, desc: 'HQ official phone number'
        optional :contact_name, type: String, desc: 'official contact name'
        optional :e_mail, type: String, desc: 'official contact e-mail'
        optional :notes, type: String, desc: 'additional notes by the Team Manager'
        optional :home_page_url, type: String, desc: 'Team Website URL'
      end
      route_param :id do
        put do
          check_jwt_session

          team = GogglesDb::Team.find_by_id(params['id'])
          team&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :teams do
      # GET /api/:version/teams
      #
      # Given some optional filtering parameters, returns the paginated list of teams found.
      #
      # == Returns:
      # The list of Teams for the specified filtering parameters as an array of JSON objects.
      # Returns exact matches for city_id, supports partial matches for the text names,
      # but no fuzzy searches are performed here. (Use dedicated /search endpoints for that.)
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Team#to_json for structure details.
      #
      desc 'List Teams'
      params do
        optional :city_id, type: Integer, desc: 'optional: associated City ID'
        optional :name, type: String, desc: 'optional: name of the Team (partial match supported)'
        optional :editable_name, type: String, desc: 'optional: name of the Team, as edited by the Team Manager (partial match supported)'
        use :pagination
      end
      # Enforcing 'max_per_page' will add the allowed range to the swagger docs and
      # cause Grape to return an error when an out-of-range value is specified.
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::Team.where(
          filtering_hash_for(params, %w[city_id])
        ).where(
          filtering_like_for(params, %w[name editable_name])
        )
      end
    end
  end
end
