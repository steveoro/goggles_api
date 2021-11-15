# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingIndividualResult API Grape controller
  #
  #   - version:  7-0.3.39
  #   - author:   Steve A.
  #   - build:    20211115
  #
  # == Note:
  # Lap data & registration entry data is stored on separated entities (MeetingEntries & Laps)
  # for MIRs. Use the Lap-dedicated endpoints to manage MIR laps.
  #
  class MeetingIndividualResultsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_individual_result do
      # GET /api/:version/meeting_individual_result/:id
      #
      # == Returns:
      # The MeetingIndividualResult instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingIndividualResult#to_json for structure details.
      #
      desc 'MeetingIndividualResult details'
      params do
        requires :id, type: Integer, desc: 'MeetingIndividualResult ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::MeetingIndividualResult.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_individual_result/:id
      #
      # Allow direct update for all the MeetingIndividualResult fields.
      # Requires CRUD grant on entity ('MeetingIndividualResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingIndividualResult details'
      params do
        requires :id, type: Integer, desc: 'MeetingIndividualResult ID'
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundredths, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :play_off, type: Boolean, desc: 'optional: true for play-offs at (or after) the end of a season; standard play otherwise'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this result does not concur in the overall rankings or scores'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :disqualified, type: Boolean, desc: 'optional: true if the swimmer has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
        optional :goggle_cup_points, type: Float, desc: 'optional: score computed for any GoggleCup associated to this specific team'
        optional :team_points, type: Float, desc: 'optional: result score contributing to overall team scoring (may be standard or meeting-specific)'
        optional :personal_best, type: Boolean, desc: 'optional: true to signal the latest personal best result for this swimmer'
        optional :season_type_best, type: Boolean, desc: 'optional: true to signal the latest seasonal best result for this swimmer'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingIndividualResult')

          meeting_individual_result = GogglesDb::MeetingIndividualResult.find_by(id: params['id'])
          meeting_individual_result&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/meeting_individual_result
      # Requires CRUD grant on entity ('MeetingIndividualResult') for requesting user.
      #
      # Creates a new MeetingIndividualResult given the specified parameters.
      #
      # == Required params:
      # - meeting_program_id (required)
      # - team_affiliation_id (required)
      # - team_id (required)
      # - swimmer_id (required)
      #
      # Timing result defaults to zero. MIRs can be created even when the actual result time
      # is not known yet.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingIndividualResult'
      params do
        requires :meeting_program_id, type: Integer, desc: 'associated MeetingProgram ID'
        requires :team_affiliation_id, type: Integer, desc: 'associated TeamAffiliation ID'
        requires :team_id, type: Integer, desc: 'associated Team ID'
        requires :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        optional :reaction_time, type: Float, desc: 'optional: reaction time'
        optional :minutes, type: Integer, desc: 'optional: result time minutes'
        optional :seconds, type: Integer, desc: 'optional: result time seconds'
        optional :hundredths, type: Integer, desc: 'optional: result time hundredths of seconds'
        optional :play_off, type: Boolean, desc: 'optional: true for play-offs at (or after) the end of a season; standard play otherwise'
        optional :out_of_race, type: Boolean, desc: 'optional: true if this result does not concur in the overall rankings or scores'
        optional :rank, type: Integer, desc: 'optional: final heat rank (1+) for this result'
        optional :standard_points, type: Float, desc: 'optional: result score computed using standard rules of this Championship'
        optional :meeting_points, type: Float, desc: 'optional: result score computed with meeting-specific rules'
        optional :disqualified, type: Boolean, desc: 'optional: true if the swimmer has been disqualified; has precedence over DisqualificationCodeType'
        optional :disqualification_code_type_id, type: Integer, desc: 'optional: Disqualification code type used only for description (not always known)'
        optional :goggle_cup_points, type: Float, desc: 'optional: score computed for any GoggleCup associated to this specific team'
        optional :team_points, type: Float, desc: 'optional: result score contributing to overall team scoring (may be standard or meeting-specific)'
        optional :personal_best, type: Boolean, desc: 'optional: true to signal the latest personal best result for this swimmer'
        optional :season_type_best, type: Boolean, desc: 'optional: true to signal the latest seasonal best result for this swimmer'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'MeetingIndividualResult')

        new_row = GogglesDb::MeetingIndividualResult.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end

      # DELETE /api/:version/meeting_individual_result/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires CRUD grant on entity ('MeetingIndividualResult') for requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingIndividualResult'
      params do
        requires :id, type: Integer, desc: 'MeetingIndividualResult ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingIndividualResult')

          return unless GogglesDb::MeetingIndividualResult.exists?(params['id'])

          GogglesDb::MeetingIndividualResult.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_individual_results do
      # GET /api/:version/meeting_individual_results
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_individual_results found.
      #
      # == Returns:
      # The list of MeetingIndividualResults for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingIndividualResult#to_json for structure details.
      #
      desc 'List MeetingIndividualResults'
      params do
        optional :meeting_program_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_affiliation_id, type: Integer, desc: 'optional: associated TeamAffiliation ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::MeetingIndividualResult.where(
            filtering_hash_for(params, %w[meeting_program_id team_affiliation_id team_id swimmer_id badge_id])
          )
        )
      end
    end
  end
end
