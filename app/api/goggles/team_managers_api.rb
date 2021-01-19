# frozen_string_literal: true

module Goggles
  # = Goggles API v3: ManagedAffiliation (team/manager) API
  #
  #   - version:  7.052
  #   - author:   Steve A.
  #   - build:    20201221
  #
  # Note: all the User/managers associated to a TeamAffiliation are already included in the
  #       response of 'GET /team_affiliation/:id'.
  #
  class TeamManagersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :team_manager do
      # POST /api/:version/team_manager
      # (ADMIN only)
      #
      # Creates a new ManagedAffiliation given the specified parameters.
      #
      # == Params:
      # - user_id: associated User as new Manager
      # - team_affiliation_id: associated TeamAffiliation
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new ManagedAffiliation'
      params do
        requires :user_id, type: Integer, desc: 'associated User ID (new Manager)'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)

        new_row = GogglesDb::ManagedAffiliation.create(params)
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
  end
end
