# frozen_string_literal: true

module Goggles
  # = Goggles API v3: SwimmingPool API Grape controller
  #
  #   - version:  1.09
  #   - author:   Steve A.
  #   - build:    20201207
  #
  class SwimmingPoolsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :swimming_pool do
      # GET /api/:version/swimming_pool/:id
      #
      # == Returns:
      # The SwimmingPool instance matching the specified +id+ as JSON.
      # See GogglesDb::SwimmingPool#to_json for structure details.
      #
      desc 'SwimmingPool details'
      params do
        requires :id, type: Integer, desc: 'SwimmingPool ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::SwimmingPool.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/swimming_pool/:id
      #
      # Allow direct update for some of the SwimmingPool fields.
      # Requires CRUD grant on entity ('TeamAffiliation') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update most SwimmingPool details'
      params do
        requires :id, type: Integer, desc: 'SwimmingPool ID'
        optional :name, type: String, desc: 'official name'
        optional :address, type: String, desc: 'address'
        optional :nick_name, type: String, desc: 'short name or nick-name for the pool'
        optional :phone_number, type: String, desc: 'phone number'
        optional :e_mail, type: String, desc: 'e-mail address'
        optional :contact_name, type: String, desc: 'contact name'
        optional :maps_uri, type: String, desc: 'online map URI'
        optional :pool_type_id, type: Integer, desc: 'associated PoolType ID'
        optional :city_id, type: Integer, desc: 'associated City ID'
        optional :lanes_number, type: Integer, desc: 'total number of pool lanes for the main pool'
        optional :multiple_pools, type: Boolean, desc: 'true: has more than 1 pool'
        optional :garden, type: Boolean, desc: 'true: has a garden area or solarium'
        optional :bar, type: Boolean, desc: 'true: includes an internal Bar'
        optional :restaurant, type: Boolean, desc: 'true: includes an internal Restaurant'
        optional :gym, type: Boolean, desc: 'true: this includes an internal Gym area'
        optional :child_area, type: Boolean, desc: 'true: includes a dedicated Children Area or Nursery'
        optional :shower_type_id, type: Integer, desc: 'associated ShowerType ID'
        optional :hair_dryer_type_id, type: Integer, desc: 'associated HairDryerType ID'
        optional :locker_cabinet_type_id, type: Integer, desc: 'associated LockerCabinetType ID'
        optional :notes, type: String, desc: 'additional notes'
        optional :read_only, type: Boolean, desc: 'true: disable any further updates'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'SwimmingPool')

          result = GogglesDb::SwimmingPool.find_by_id(params['id'])
          # Reject altering read_only attribute unless user has admin grants:
          params.delete('read_only') unless GogglesDb::GrantChecker.admin?(api_user)
          # Don't do anything if we're left with no editing parameters:
          result&.update!(declared(params, include_missing: false)) unless params.keys.size == 1
        end
      end
    end

    resource :swimming_pools do
      # GET /api/:version/swimming_pools
      #
      # Given some optional filtering parameters, returns the paginated list of SwimmingPools found.
      #
      # == Returns:
      # The list of SwimmingPools for the specified filtering parameters as an array of JSON objects.
      # Returns exact matches given the specified optional filters (some support partial string matches).
      # No fuzzy searches are performed here.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::SwimmingPool#to_json for structure details.
      #
      desc 'List SwimmingPools'
      params do
        optional :name, type: String, desc: 'optional: name (partial match supported)'
        optional :address, type: String, desc: 'optional: address (partial match supported)'
        optional :nick_name, type: String, desc: 'optional: nick-name (partial match supported)'
        optional :pool_type_id, type: Integer, desc: 'optional: associated PoolType ID'
        optional :city_id, type: Integer, desc: 'optional: associated City ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::SwimmingPool.where(
          filtering_hash_for(params, %w[pool_type_id city_id])
        ).where(
          filtering_like_for(params, %w[name address nick_name])
        )
      end
    end
  end
end
