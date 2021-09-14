# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Admin Grants API (list-only)
  #
  #   - version:  7-0.03.30
  #   - author:   Steve A.
  #   - build:    20210913
  #
  class AdminGrantsAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :admin_grants do
      # GET /api/:version/admin_grants
      #
      # Returns the paginated list of all existing AdminGrant rows found using the specified filters.
      #
      # == Params:
      # - user_id: filters existing grants by user_id
      # - entity: filters existing grants by entity name (model name without the "GogglesDb::" namespace prefix)
      #
      # == Returns:
      # The JSON list of the AdminGrant rows found.
      #
      desc 'List existing AdminGrants'
      params do
        optional :user_id, type: Integer, desc: 'optional: filters existing grants by user_id'
        optional :entity, type: String, desc: 'optional: filters existing grants by entity name (model name without \'GogglesDb::\' namespace prefix)'
      end
      get do
        reject_unless_authorized_admin(check_jwt_session)

        paginate(
          GogglesDb::AdminGrant.where(
            filtering_hash_for(params, %w[user_id entity])
          )
        )
      end
    end
  end
end
