# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingRelayResult API Grape controller
  #
  #   - version:  7.067
  #   - author:   Steve A.
  #   - build:    20210122
  #
  # == Note:
  # Relay entries are more than often finalized during the Meeting itself and
  # data is frequently collected "on the field".
  #
  # MRRs (countrary to MIRs) incorporate registration entries data together with their
  # actual ending time result.
  #
  # This allows a remote client to prepare the relay setup directly when posting
  # the relay entry itself; the timing result can be set later on when the relay is over.
  #
  # Lap data for MRRs is stored inside MeetingRelaySwimmers (MRSs).
  # Use MRS dedicated endpoints to manage relay laps (& swimmers).
  #
  class MeetingRelayResultsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_relay_result do
      # GET /api/:version/meeting_relay_result/:id
      #
      # == Returns:
      # The MeetingRelayResult instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingRelayResult#to_json for structure details.
      #
      desc 'MeetingRelayResult details'
      params do
        requires :id, type: Integer, desc: 'MeetingRelayResult ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::MeetingRelayResult.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/meeting_relay_result/:id
      #
      # Allow direct update for all the MeetingRelayResult fields.
      # Requires CRUD grant on entity ('MeetingRelayResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingRelayResult details'
      params do
        # MIRs & MRRs common fields:
        requires :id, type: Integer, desc: 'MeetingRelayResult ID'
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundreds, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :play_off, type: Boolean, desc: 'optional: true for play-offs at (or after) the end of a season; standard play otherwise'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this result does not concur in the overall rankings or scores'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :disqualified, type: Boolean, desc: 'optional: true if this team relay has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
        # Entries-related:
        optional :relay_header, type: String, desc: 'optional: descriptive code or number used whenever the same team has registered more than one relay'
        optional :entry_time_type_id, type: Integer, desc: 'optional: associated EntryTimeType ID for the relay entry'
        optional :entry_minutes, type: Integer, desc: 'optional: minutes for the registration entry time'
        optional :entry_seconds, type: Integer, desc: 'optional: seconds for the registration entry time'
        optional :entry_hundreds, type: Integer, desc: 'optional: hundredths of seconds for the registration entry time'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingRelayResult')

          meeting_relay_result = GogglesDb::MeetingRelayResult.find_by_id(params['id'])
          meeting_relay_result&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_relay_result
      # Requires CRUD grant on entity ('MeetingRelayResult') for requesting user.
      #
      # Creates a new MeetingRelayResult given the specified parameters.
      #
      # == Required params:
      # - meeting_program_id (required)
      # - team_affiliation_id (required)
      # - team_id (required)
      #
      # Timing result defaults to zero. MRRs can be created even when the actual result time
      # is not known yet or just to create a relay entry (which will subsequently store the final
      # result time when it becomes known or available).
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingRelayResult'
      params do
        # MIRs & MRRs common fields:
        requires :meeting_program_id, type: Integer, desc: 'associated MeetingProgram ID'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundreds, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :play_off, type: Boolean, desc: 'optional: true for play-offs at (or after) the end of a season; standard play otherwise'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this result does not concur in the overall rankings or scores'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :disqualified, type: Boolean, desc: 'optional: true if this team relay has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
        # Entries-related:
        optional :relay_header, type: String, desc: 'optional: descriptive code or number used whenever the same team has registered more than one relay'
        optional :entry_time_type_id, type: Integer, desc: 'optional: associated EntryTimeType ID for the relay entry'
        optional :entry_minutes, type: Integer, desc: 'optional: minutes for the registration entry time'
        optional :entry_seconds, type: Integer, desc: 'optional: seconds for the registration entry time'
        optional :entry_hundreds, type: Integer, desc: 'optional: hundredths of seconds for the registration entry time'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'MeetingRelayResult')

        new_row = GogglesDb::MeetingRelayResult.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            500,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_relay_result/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('MeetingRelayResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingRelayResult'
      params do
        requires :id, type: Integer, desc: 'MeetingRelayResult ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingRelayResult')

          return unless GogglesDb::MeetingRelayResult.exists?(params['id'])

          GogglesDb::MeetingRelayResult.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_relay_results do
      # GET /api/:version/meeting_relay_results
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_relay_results found.
      #
      # == Returns:
      # The list of MeetingRelayResults for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingRelayResult#to_json for structure details.
      #
      desc 'List MeetingRelayResults'
      params do
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::MeetingRelayResult.where(
            filtering_hash_for(params, %w[meeting_program_id team_affiliation_id team_id])
          )
        )
      end
    end
  end
end
