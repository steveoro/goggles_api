# frozen_string_literal: true

module Goggles
  # = Goggles API v3: BadgePayment API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  class BadgePaymentsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :badge_payment do
      # GET /api/:version/badge_payment/:id
      #
      # Requires CRUD grant on entity ('BadgePayment') for the requesting user.
      #
      # == Returns:
      # The BadgePayment instance matching the specified +id+ as JSON.
      # See GogglesDb::BadgePayment#to_json for structure details.
      #
      desc 'BadgePayment details'
      params do
        requires :id, type: Integer, desc: 'BadgePayment ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'BadgePayment')
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::BadgePayment.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/badge_payment/:id
      #
      # Allows direct update for all the BadgePayment fields.
      # Requires CRUD grant on entity ('BadgePayment') for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update BadgePayment details'
      params do
        requires :id, type: Integer, desc: 'BadgePayment ID'
        optional :payment_date, type: String, desc: 'optional: payment date in ISO format'
        optional :amount, type: Float, desc: 'optional: payment amount'
        optional :notes, type: String, desc: 'optional: free text notes'
        optional :manual, type: Boolean, desc: 'optional: true for cash payments made by hand'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :user_id, type: Integer, desc: 'optional: User ID associated to the payment (either the team manager or the user)'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'BadgePayment')

          badge_payment = GogglesDb::BadgePayment.find_by(id: params['id'])
          badge_payment&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/badge_payment
      #
      # Creates a new BadgePayment row given the specified parameters.
      # Requires CRUD grant on entity ('BadgePayment') for the requesting user.
      #
      # == Required Params:
      # - payment_date: payment date in ISO format
      # - amount: payment amount
      # - badge_id: the Badge ID associated to the payment
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new BadgePayment row'
      params do
        requires :payment_date, type: String, desc: 'payment date in ISO format'
        requires :amount, type: Float, desc: 'payment amount'
        requires :badge_id, type: Integer, desc: 'associated Badge ID'
        optional :user_id, type: Integer, desc: 'User ID associated to the payment (either the team manager or the user)'
        optional :notes, type: String, desc: 'optional: free text notes'
        optional :manual, type: Boolean, desc: 'optional: true for cash payments made by hand'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'BadgePayment')

        new_row = GogglesDb::BadgePayment.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/badge_payment/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('BadgePayment') for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a BadgePayment'
      params do
        requires :id, type: Integer, desc: 'BadgePayment ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'BadgePayment')

          return unless GogglesDb::BadgePayment.exists?(params['id'])

          GogglesDb::BadgePayment.destroy(params['id']).destroyed?
        end
      end
    end

    resource :badge_payments do
      # GET /api/:version/badge_payments
      #
      # Given some optional filtering parameters, returns the paginated list of badge_payments found.
      # Requires CRUD grant on entity ('BadgePayment') for the requesting user.
      #
      # == Returns:
      # The list of BadgePayments for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::BadgePayment#to_json for structure details.
      #
      desc 'List BadgePayments'
      params do
        optional :from_date, type: String, desc: 'optional: starting payment date in ISO format (all payments on or after this date)'
        optional :user_id, type: Integer, desc: 'optional: associated User ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :manual, type: Boolean, desc: 'optional: true for cash payments made by hand'
        use :pagination
      end
      paginate
      get do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'BadgePayment')

        paginate(
          GogglesDb::BadgePayment.where(filtering_hash_for(params, %w[user_id badge_id manual]))
                                 .where(filtering_for_single_parameter('payment_date >= ?', params, 'from_date'))
                                 .order('badge_payments.id DESC')
        )
      end
    end
  end
end
