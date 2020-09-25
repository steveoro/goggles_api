# frozen_string_literal: true

module Goggles
  # = Goggles API v3: TeamAffiliation API Grape controller
  #
  #   - version:  1.00
  #   - author:   Steve A.
  #   - build:    20200925
  #
  class TeamAffiliationsAPI < Grape::API
    format        :json
    content_type  :json, 'application/json'

    resource :team_affiliation do
      # GET /api/:version/team_affiliation/:id
      #
      # == Returns:
      # The TeamAffiliation instance matching the specified +id+ as JSON.
      # See GogglesDb::TeamAffiliation#to_json for structure details.
      #
      desc 'TeamAffiliation details'
      params do
        requires :id, type: Integer, desc: 'TeamAffiliation ID'
      end
      route_param :id do
        get do
          !CmdAuthorizeAPIRequest.new(headers).call.success? &&
            error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

          GogglesDb::TeamAffiliation.find_by_id(params['id'])
        end
      end
    end
  end
end
