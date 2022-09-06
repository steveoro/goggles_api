# frozen_string_literal: true

module Goggles
  # = Goggles API v3: MeetingReservation API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  class MeetingReservationsAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :meeting_reservation do
      # GET /api/:version/meeting_reservation/:id
      #
      # == Returns:
      # The MeetingReservation instance matching the specified +id+ as JSON.
      # See GogglesDb::MeetingReservation#to_json for structure details.
      #
      desc 'MeetingReservation details'
      params do
        requires :id, type: Integer, desc: 'MeetingReservation ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          # Support locale override:
          I18n.locale = params['locale'] if params['locale'].present?

          GogglesDb::MeetingReservation.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/meeting_reservation/:id
      #
      # Allow direct update for most of the MeetingReservation fields, including children event reservations.
      # Requires CRUD grant on entity ('MeetingReservation') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update MeetingReservation details'
      params do
        requires :id, type: Integer, desc: 'MeetingReservation ID'
        optional :not_coming, type: Boolean, desc: 'optional: true if the swimmer is not attending at all at this Meeting'
        optional :confirmed, type: Boolean, desc: 'optional: true if the swimmer has already confirmed enrolling or presence at the Meeting'
        optional :notes, type: String, desc: 'optional: additional free notes'
        optional :events, type: Array do
          requires :id, type: Integer, desc: 'MeetingEventReservation ID (required whenever including any of the nested fields)'
          optional :minutes, type: Integer, desc: 'optional: minutes for the entry timing'
          optional :seconds, type: Integer, desc: 'optional: seconds for the entry timing'
          optional :hundredths, type: Integer, desc: 'optional: hundredths of seconds for the entry timing'
          optional :accepted, type: Boolean, desc: 'optional: true if the swimmer has accepted taking part in this event'
          optional :notes, type: String, desc: 'optional: additional free notes'
        end
        optional :relays, type: Array do
          requires :id, type: Integer, desc: 'MeetingRelayReservation ID (required whenever including any of the nested fields)'
          optional :accepted, type: Boolean, desc: 'optional: true if the swimmer has accepted taking part in this relay event'
          optional :notes, type: String, desc: 'optional: additional free notes'
        end
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingReservation')

          # Update children reservation rows:
          update_subentity_details(params, 'events', GogglesDb::MeetingEventReservation)
          update_subentity_details(params, 'relays', GogglesDb::MeetingRelayReservation)

          # Update parent reservation:
          parent_updates = params.reject { |key, _v| %w[events relays].include?(key) }
          meeting_reservation = GogglesDb::MeetingReservation.find_by(id: params['id'])
          meeting_reservation&.update!(user_id: api_user.id) # set latests changes' user ID
          meeting_reservation&.update!(declared(parent_updates, include_missing: false))
        end
      end

      # POST /api/:version/meeting_reservation
      #
      # Creates a new MeetingReservation given the specified parameters, together
      # with the list of children reservations needed for the associated events & relays
      # found existing for this Meeting definition.
      # (Thus, the Meeting needs to be already defined for the "reservation matrix" to result complete.)
      #
      # Requires CRUD grant on entity ('MeetingReservation') for the requesting user.
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create new MeetingReservation row with event & relay reservation details'
      params do
        requires :badge_id, type: Integer, desc: 'associated Badge ID'
        requires :meeting_id, type: Integer, desc: 'associated Meeting ID'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'MeetingReservation')

        cmd = GogglesDb::CmdCreateReservation.call(
          GogglesDb::Badge.find_by(id: params['badge_id']),
          GogglesDb::Meeting.find_by(id: params['meeting_id']),
          api_user
        )
        error!(I18n.t('api.message.creation_failure'), 422, 'X-Error-Detail' => cmd.errors[:msg]) unless cmd.success?

        { msg: I18n.t('api.message.generic_ok'), new: cmd.result }
      end

      # DELETE /api/:version/meeting_reservation/:id
      #
      # Allows to delete a specific row with its associated details given its ID.
      # Requires CRUD grant on entity ('MeetingReservation') for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a MeetingReservation'
      params do
        requires :id, type: Integer, desc: 'MeetingReservation ID'
      end
      route_param :id do
        delete do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'MeetingReservation')

          return unless GogglesDb::MeetingReservation.exists?(params['id'])

          GogglesDb::MeetingReservation.destroy(params['id']).destroyed?
        end
      end
    end

    resource :meeting_reservations do
      # GET /api/:version/meeting_reservations
      #
      # Given some optional filtering parameters, returns the paginated list of meeting_reservations found.
      #
      # == Returns:
      # The list of MeetingReservations for the specified filtering parameters as an array of JSON objects.
      # Returns the exact matches for any parameter value.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::MeetingReservation#to_json for structure details.
      #
      desc 'List MeetingReservations'
      params do
        optional :meeting_id, type: Integer, desc: 'optional: associated MeetingProgram ID'
        optional :team_id, type: Integer, desc: 'optional: associated Team ID'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
        optional :badge_id, type: Integer, desc: 'optional: associated Badge ID'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate(
          GogglesDb::MeetingReservation.where(
            filtering_hash_for(params, %w[meeting_id team_id swimmer_id badge_id])
          ).order('meeting_reservations.id DESC')
        )
      end
    end
  end
end
