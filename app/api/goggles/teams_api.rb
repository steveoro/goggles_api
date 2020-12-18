# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Team API Grape controller
  #
  #   - version:  7.051
  #   - author:   Steve A.
  #   - build:    20201218
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
      # Requires CRUD grant on entity ('TeamAffiliation') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Team details'
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
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Team')

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
      # Returns exact matches for city_id; supports FULLTEXT search by the generic 'name' parameter
      # which acts on the 'name', 'editable_name' and 'name_variations' fields.
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
        optional :name, type: String, desc: 'optional: generic FULLTEXT name search on name, editable_name & name_variations fields'
        optional :city_id, type: Integer, desc: 'optional: associated City ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          filtering_fulltext_search_for(GogglesDb::Team, params['name'])
            .where(filtering_hash_for(params, %w[city_id]))
        )
      end
    end
  end
end
