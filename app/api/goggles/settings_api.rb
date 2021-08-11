# frozen_string_literal: true

# = Goggles API v3: Setting API Grape controller
#
#   - version:  7-0.3.25
#   - author:   Steve A.
#   - build:    20210810
#
module Goggles
  # = Settings API Grape controller
  #
  # Provides access & management for internal app settings. (Admin-only)
  #
  # Settings are internally stored as a stand-alone table, grouped by key names but linked to 2 data table
  # origins:
  # - app_parameters => any settings group related to the app context; all app settings are stored on row ID 1 (versioning row)
  # - users => any user preferences; any user instance may access to its own 'prefs' group of settings
  #
  # == Valid group key names
  # Any GogglesDb::AppParameter::SETTINGS_GROUPS name or 'prefs', for accessing user preferences.
  #
  # === User preferences (defaults)
  # The logged-in Admin can only change his/her own user prefs.
  #
  # - hide_search_help (false)
  # - hide_dashboard_help (false)
  # - notify_my_meetings (false)
  # - notify_new_team_meeting (false)
  # - notify_any_meeting (false)
  #
  class SettingsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :setting do
      # GET /api/:version/setting/:group_key
      #
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # The Setting Hash for the specified +group_name+ as JSON.
      #
      desc 'Retrieve Setting Group values'
      params do
        requires :group_key, type: String, desc: 'Setting group name'
      end
      route_param :group_key do
        get do
          curr_admin = check_jwt_session
          cfg_row = retrieve_settings_row(curr_admin, params['group_key'])
          cfg_row.settings(params['group_key'].to_sym).value
        end
      end

      # PUT /api/:version/setting/:group_key
      #
      # Allows direct update for any Setting key. The key will be automatically
      # added to the group if missing.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update a single Setting key'
      params do
        requires :group_key, type: String, desc: 'Setting group name'
        requires :key, type: String, desc: 'Setting key'
        requires :value, type: String, desc: 'Setting value for the specified key'
      end
      route_param :group_key do
        put do
          curr_admin = check_jwt_session

          cfg_row = retrieve_settings_row(curr_admin, params['group_key'])
          settings_group_value_setter(
            cfg_row.settings(params['group_key'].to_sym),
            params['key'],
            params['value']
          )
          cfg_row.save!
        end
      end

      # DELETE /api/:version/setting/:group_key
      #
      # Allows to delete a specific settings value given its key.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Deletes a single Setting key'
      params do
        requires :group_key, type: String, desc: 'Setting group name'
        requires :key, type: String, desc: 'Setting key to be deleted'
      end
      route_param :group_key do
        delete do
          curr_admin = check_jwt_session

          cfg_row = retrieve_settings_row(curr_admin, params['group_key'])
          settings_group_value_setter(
            cfg_row.settings(params['group_key'].to_sym),
            params['key'],
            nil
          )
          cfg_row.save!
        end
      end
    end
  end
end
