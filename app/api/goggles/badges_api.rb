# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Badge API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200925
  #
  class BadgesAPI < Grape::API
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
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

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
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          badge = GogglesDb::Badge.find_by_id(params['id'])
          badge&.update!(declared(params, include_missing: false))
        end
      end
    end
  end
end
