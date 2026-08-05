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
      desc 'APIDailyUse details' do
        success Goggles::Entities::APIDailyUseEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
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
      desc 'Update APIDailyUse details' do
        success code: 200, message: 'APIDailyUse updated'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
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
      desc 'Deletes a single APIDailyUse row' do
        success code: 200, message: 'APIDailyUse deleted'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
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
      desc 'List APIDailyUses' do
        is_array true
        success Goggles::Entities::APIDailyUseEntity
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
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
            .order(id: :desc)
        ).map(&:to_hash)
      end

      # GET /api/:version/api_daily_uses/summary
      #
      # Returns an aggregated summary of API usage for the specified period,
      # including top requested pages, top abusive IPs, top user-agents and
      # overall request totals.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # A JSON Hash with the following keys:
      # - top_routes:    array of { route, total_count }
      # - top_ips:       array of { ip, total_count }
      # - top_agents:    array of { user_agent, total_count }
      # - totals:        { requests, ip_requests, route_requests }
      #
      desc 'APIDailyUses usage summary' do
        success code: 200, message: 'Summary returned'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        optional :start_date, type: Date, desc: 'summary period start date (defaults to 7 days ago)'
        optional :end_date,   type: Date, desc: 'summary period end date (defaults to today)'
        optional :threshold,  type: Integer, desc: 'IP route count threshold for abusive IPs (default: 500)'
        optional :limit,      type: Integer, desc: 'maximum number of top rows to return (default: 10)'
      end
      get :summary do
        reject_unless_authorized_admin(check_jwt_session)

        day_from = params['start_date'] || (Time.zone.today - 7.days)
        day_to   = params['end_date']   || Time.zone.today
        threshold = params['threshold'] || 500
        limit = params['limit']         || 10

        {
          top_routes: GogglesDb::APIDailyUse.top_routes(day_from:, day_to:, limit:)
                                            .map { |row| { route: row.route, total_count: row.total_count.to_i } },
          top_ips: GogglesDb::APIDailyUse.top_ip_routes(day_from:, day_to:, threshold:, limit:)
                                         .map { |row| { ip: row.route.to_s.delete_prefix('REQ-'), total_count: row.total_count.to_i } },
          top_agents: GogglesDb::APIDailyUseAgent.top_agents(day_from:, day_to:, limit:)
                                                 .map { |row| { user_agent: row.user_agent, total_count: row.total_count.to_i } },
          totals: GogglesDb::APIDailyUse.daily_totals(day_from:, day_to:)
        }
      end

      # DELETE /api/:version/api_daily_uses
      #
      # Allows to delete several rows older than a specified given date.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # the number of deleted rows when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Deletes several rows older than a specified given date' do
        success code: 200, message: 'Rows deleted'
        failure [
          [401, 'Unauthorized - Missing or invalid JWT or grants']
        ]
        headers Authorization: { description: 'Bearer JWT token.', required: true }
      end
      params do
        requires :day, type: Date, desc: 'date (day) limit: any row older than (<) this specified day will be erased forever'
      end
      delete do
        reject_unless_authorized_admin(check_jwt_session)

        return unless GogglesDb::APIDailyUse.exists?(['day < ?', params['day']])

        # We don't care about #destroy callbacks here:
        GogglesDb::APIDailyUse.where(day: ...(params['day'])).delete_all
      end
    end
  end
end
