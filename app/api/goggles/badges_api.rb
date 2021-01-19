# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Badge API Grape controller
  #
  #   - version:  7.053
  #   - author:   Steve A.
  #   - build:    20201222
  #
  class BadgesAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :badge do
      # GET /api/:version/badge/:id
      #
      # == Returns:
      # The Badge instance matching the specified +id+ as JSON; an empty result when not found.
      # See GogglesDb::Badge#to_json for structure details.
      #
      desc 'Badge details'
      params do
        requires :id, type: Integer, desc: 'Badge ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Badge.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/badge/:id
      #
      # Allow direct update for the Badge number and other limited fields.
      # Requires CRUD grant on entity ('Badge') for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update Badge details'
      params do
        requires :id, type: Integer, desc: 'Badge ID (required)'
        requires :number, type: String, desc: 'displayed number or code for the Badge (required)'
        optional :entry_time_type_id, type: Integer, desc: 'associated EntryTimeType ID'
        optional :off_gogglecup, type: Boolean, desc: 'true if the swimmer does not run for the bespoke GoggleCup'
        optional :fees_due, type: Boolean, desc: 'true: the Swimmer has to pay additional meeting fees for the Championship; false: the Team provides'
        optional :badge_due, type: Boolean, desc: 'true: the Swimmer has to pay the badge registration; false: the Team provides'
        optional :relays_due, type: Boolean, desc: 'true: the Swimmer has to pay any relay event in the Championship; false: the Team provides'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'Badge')

          badge = GogglesDb::Badge.find_by_id(params['id'])
          badge&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/badge
      # (ADMIN only)
      #
      # Creates a new Badge given the specified parameters.
      #
      # == Main Params:
      # - swimmer_id (required)
      # - team_affiliation_id (required)
      # - season_id (required)
      # - team_id (required)
      # - category_type_id (required)
      # - entry_time_type_id (required)
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new Badge'
      params do
        requires :swimmer_id, type: Integer, desc: 'associated Swimmer ID (required)'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID (required)'
        requires :season_id, type: Integer, desc: 'associated Season ID (required)'
        requires :team_id, type: Integer, desc: 'associated Team ID (required)'
        requires :category_type_id, type: Integer, desc: 'associated CategoryType ID (required)'
        requires :entry_time_type_id, type: Integer, desc: 'associated EntryTimeType ID (required)'
        optional :number, type: String, desc: 'displayed number or code for the Badge'
        optional :off_gogglecup, type: Boolean, desc: 'true if the swimmer does not run for the bespoke GoggleCup'
        optional :fees_due, type: Boolean, desc: 'true: the Swimmer has to pay additional meeting fees for the Championship; false: the Team provides'
        optional :badge_due, type: Boolean, desc: 'true: the Swimmer has to pay the badge registration; false: the Team provides'
        optional :relays_due, type: Boolean, desc: 'true: the Swimmer has to pay any relay event in the Championship; false: the Team provides'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)

        new_row = GogglesDb::Badge.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            500,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end
    end

    resource :badges do
      # GET /api/:version/badges
      #
      # Given some optional filtering parameters, returns the paginated list of badges found.
      #
      # == Returns:
      # The list of Badges for the specified filtering parameters as an array of JSON objects.
      # Returns only *exact* matches, no fuzzy or partial searches are done.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Badge#to_json for structure details.
      #
      desc 'List Badges'
      params do
        optional :team_id, type: Integer, desc: 'associated Team ID'
        optional :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
        optional :season_id, type: Integer, desc: 'associated Season ID'
        optional :swimmer_id, type: Integer, desc: 'associated Swimmer ID'
        use :pagination
      end
      # Enforcing 'max_per_page' will add the allowed range to the swagger docs and
      # cause Grape to return an error when an out-of-range value is specified.
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::Badge.where(
          filtering_hash_for(
            params,
            %w[team_id team_affiliation_id season_id swimmer_id]
          )
        )
      end
    end
  end
end
