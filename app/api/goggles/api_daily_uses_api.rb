# frozen_string_literal: true

# = Goggles API v3
#
#   - version:  7-0.3.25
#   - author:   Steve A.
#   - build:    20210810
#
module Goggles
  # = APIDailyUses API Grape controller
  #
  # Provides access & management to internal usage stats
  #
  class APIDailyUsesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :api_daily_use do
      # GET /api/:version/api_daily_use/:id
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The APIDailyUse instance matching the specified +id+ as JSON.
      #
      desc 'APIDailyUse details'
      params do
        requires :id, type: Integer, desc: 'APIDailyUse ID'
      end
      route_param :id do
        get do
          reject_unless_authorized_admin(check_jwt_session)

          GogglesDb::APIDailyUse.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/api_daily_use/:id
      #
      # Allows direct update for most of the APIDailyUse fields.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update APIDailyUse details'
      params do
        requires :id, type: Integer, desc: 'APIDailyUse ID'
        optional :day, type: Date, desc: 'optional: date (day) for the API usage counter'
        optional :route, type: String, desc: 'optional: new base route of the API call counter'
        optional :count, type: Integer, desc: 'optional: new counter value'
      end
      route_param :id do
        put do
          reject_unless_authorized_admin(check_jwt_session)

          api_daily_use = GogglesDb::APIDailyUse.find_by(id: params['id'])
          api_daily_use&.update!(declared(params, include_missing: false))
        end
      end

      # DELETE /api/:version/api_daily_use/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Deletes a single APIDailyUse row'
      params do
        requires :id, type: Integer, desc: 'APIDailyUse ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::APIDailyUse.exists?(params['id'])

          GogglesDb::APIDailyUse.destroy(params['id']).destroyed?
        end
      end
    end

    resource :api_daily_uses do
      # GET /api/:version/api_daily_uses
      #
      # Given some optional filtering parameters, returns the paginated list of api_daily_uses found.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The list of APIDailyUses for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      #
      desc 'List APIDailyUses'
      params do
        optional :day, type: Date, desc: 'optional: date (day) for which the API usage counters must be retrieved'
        optional :route, type: String, desc: 'optional: base route identifying the type of API call; LIKE filtering is applied'
        use :pagination
      end
      paginate
      get do
        reject_unless_authorized_admin(check_jwt_session)

        paginate(
          GogglesDb::APIDailyUse
            .where(filtering_hash_for(params, %w[day]))
            .where(filtering_like_for(params, %w[route]))
        ).map(&:to_hash)
      end

      # DELETE /api/:version/api_daily_uses
      #
      # Allows to delete several rows older than a specified given date.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # the number of deleted rows when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Deletes several rows older than a specified given date'
      params do
        requires :day, type: Date, desc: 'date (day) limit: any row older than (<) this specified day will be erased forever'
      end
      delete do
        reject_unless_authorized_admin(check_jwt_session)

        return unless GogglesDb::APIDailyUse.exists?(['day < ?', params['day']])

        # We don't care about #destroy callbacks here:
        GogglesDb::APIDailyUse.where('day < ?', params['day']).delete_all
      end
    end
  end
end
