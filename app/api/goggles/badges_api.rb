# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Badge API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class BadgesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

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
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some Badge details'
      params do
        requires :id, type: Integer, desc: 'Badge ID'
        requires :number, type: String, desc: 'displayed number or code for the Badge'
        optional :entry_time_type_id, type: Integer, desc: 'associated EntryTimeType ID'
        optional :has_to_pay_fees, type: Boolean, desc: 'true: the Swimmer has to pay additional meeting fees for the Championship; false: the Team provides'
        optional :has_to_pay_badge, type: Boolean, desc: 'true: the Swimmer has to pay the badge registration; false: the Team provides'
        optional :has_to_pay_relays, type: Boolean, desc: 'true: the Swimmer has to pay any relay event in the Championship; false: the Team provides'
      end
      route_param :id do
        put do
          check_jwt_session

          badge = GogglesDb::Badge.find_by_id(params['id'])
          badge&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :badges do
      # GET /api/:version/badges
      #
      # Given some optional filtering parameters, returns the paginated list of associated badges.
      #
      # == Returns:
      # The list of Badges for the specified filtering parameters as an array of JSON objects.
      # Pagination links are stored in the response headers.
      # See GogglesDb::Badge#to_json for structure details.
      #
      desc 'List Badges'
      params do
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :season_id, type: Integer, desc: 'optional: associated Season ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        use :pagination
      end
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
