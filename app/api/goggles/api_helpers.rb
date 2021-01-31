# frozen_string_literal: true

module Goggles
  # = APIHelpers module
  #
  #   Wrapper module for helper methods used by the API.
  #
  #   - version:  7.072
  #   - author:   Steve A.
  #   - build:    20210126
  #
  module APIHelpers
    extend Grape::API::Helpers

    # Default parameter setup for date period/range
    params :period do
      optional :start_date
      optional :end_date
    end

    # Default parameter setup for pagination
    params :pagination do
      optional :page,         type: Integer, desc: 'current page'
      optional :per_page,     type: Integer, desc: 'default: 25 rows per page'
      optional :max_per_page, type: Integer, desc: 'Max rows per page (no default)'
    end
    #-- -----------------------------------------------------------------------
    #++

    # Yields the 'JWT invalid' error if the session token or the credentials are invalid.
    # On success, returns the authenticated *User* instance.
    def check_jwt_session
      authorization = CmdAuthorizeAPIRequest.new(headers).call
      !authorization.success? &&
        error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))

      # Update stats using as key a path stripped of all IDs & return authorization result:
      # (Note: for some tests negative IDs may be used, so we consider those too)
      GogglesDb::APIDailyUse.increase_for!("#{request.env['REQUEST_METHOD']} #{request.path.gsub(%r{/-?\d+}, '/:id')}")
      authorization.result
    end

    # Helps to reject incoming requests when the maintenance status is toggled ON.
    # (Only few endpoints may be deemed critical enough to include this helper; the majority should be designed
    #  fault tolerant enough)
    def reject_during_maintenance
      return unless GogglesDb::AppParameter.maintenance?

      error!(I18n.t('api.message.status.maintenance'), 401, 'X-Error-Detail' => I18n.t('api.message.status.maintenance.maintenance_description'))
    end

    # Yields a parameter error if the specified +entity_id+ is not found among +entity_class+ rows.
    # Returns the entity row when found.
    def reject_unless_found(entity_id, entity_class)
      result_row = entity_class.find_by_id(entity_id)
      error!(I18n.t('api.message.invalid_parameter'), 401, 'X-Error-Detail' => "#{entity_class}, ID: #{entity_id}") unless result_row
      result_row
    end

    # Yields the 'Unauthorized' error if the user does not have associated grants for CRUD operations
    # on the specified entity.
    def reject_unless_authorized_for_crud(user, entity_name)
      !GogglesDb::GrantChecker.crud?(user, entity_name) &&
        error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.invalid_user_grants'))
    end

    # Yields the 'Unauthorized' error if the user does not have generic admin grants.
    def reject_unless_authorized_admin(user)
      !GogglesDb::GrantChecker.admin?(user) &&
        error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.invalid_user_grants'))
    end

    # Returns a where-condition Hash (with exact matches) given a field list and the current params Hash.
    #
    # Assumes a 1:1 mapping and same-named columns for both field_list (which are the column names)
    # and the params.keys names.
    def filtering_hash_for(params, field_list)
      filtering = {}
      field_list.each do |field_name|
        filtering.merge!(field_name => params[field_name]) if params[field_name].present?
      end
      ActiveRecord::Base.sanitize_sql_for_conditions(filtering)
    end

    # Similarly to filtering_hash_for, returns a WHERE-condition Hash but based on 'LIKE' matches
    # instead of perfect matches, given the specified field list and the current params Hash.
    # Returns nil when no condition is appliable.
    #
    # Assumes a 1:1 mapping and same-named columns for both field_list (which are the column names)
    # and the params.keys names.
    def filtering_like_for(params, field_list)
      like_condition = field_list.dup.keep_if { |field_name| params.key?(field_name) }
                                 .map { |field_name| "(#{field_name} LIKE ?)" }.join(' AND ')
      field_values = params.dup.keep_if { |key, _v| field_list.include?(key) }
                           .values.map { |value| "%#{value}%" }
      ActiveRecord::Base.sanitize_sql_array([like_condition, field_values].flatten) unless field_values.empty?
    end

    # Returns a filtering WHERE condition or nil given the param. name.
    # +sql_condition+ must be an SQL string based on a single parameter using'?' as
    # placeholders for any value. Multiple occurrences of the same value are supported.
    def filtering_for_single_parameter(sql_condition, params, field_name)
      return nil unless params[field_name].present?

      ActiveRecord::Base.sanitize_sql_array(
        [sql_condition, [params[field_name]] * sql_condition.count('?')].flatten
      )
    end

    # Same as 'filtering_for_single_parameter', but for a LIKE clause.
    # Returns a filtering WHERE condition or nil given the param. name.
    # +sql_condition+ must be an SQL string based on a single parameter using'?' as
    # placeholders for any value. Multiple occurrences of the same value are supported.
    def filtering_like_for_single_parameter(sql_condition, params, field_name)
      return nil unless params[field_name].present?

      ActiveRecord::Base.sanitize_sql_array(
        [sql_condition, ["%#{params[field_name]}%"] * sql_condition.count('?')].flatten
      )
    end

    # Assuming domain_class is a relation or a sibling of ActiveRecord::Base,
    # returns the 'for_name' full-text search scope or the full data domain if the search term is not present.
    def filtering_fulltext_search_for(domain_class, search_term)
      search_term.present? ? domain_class.for_name(search_term) : domain_class
    end
    #-- -----------------------------------------------------------------------
    #++

    # Returns the Class for the specified +table_name+, or +nil+ if the
    # name is unsupported or not allowed.
    #
    # The method should include only siblings of GogglesDb::ApplicationLookupEntity.
    #
    # == Params
    # - table_name: the string name of the lookup table
    #
    # == Returns
    # The corresponding Model class or nil, if the name is unsupported.
    #
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def lookup_entity_class_for(table_name)
      case table_name
      when 'coach_level_types'
        GogglesDb::CoachLevelType
      when 'day_part_types'
        GogglesDb::DayPartType
      when 'disqualification_code_types'
        GogglesDb::DisqualificationCodeType
      when 'edition_types'
        GogglesDb::EditionType
      when 'entry_time_types'
        GogglesDb::EntryTimeType
      when 'event_types'
        GogglesDb::EventType
      when 'gender_types'
        GogglesDb::GenderType
      when 'hair_dryer_types'
        GogglesDb::HairDryerType
      when 'heat_types'
        GogglesDb::HeatType
      when 'locker_cabinet_types'
        GogglesDb::LockerCabinetType
      when 'medal_types'
        GogglesDb::MedalType
      when 'pool_types'
        GogglesDb::PoolType
      when 'record_types'
        GogglesDb::RecordType
      when 'shower_types'
        GogglesDb::ShowerType
      when 'stroke_types'
        GogglesDb::StrokeType
      when 'swimmer_level_types'
        GogglesDb::SwimmerLevelType
      when 'timing_types'
        GogglesDb::TimingType
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity
    #-- -----------------------------------------------------------------------
    #++

    # Updates any existing sub-entity list of rows.
    #
    # The detail_key in the parent hash points to an array of detail parameters that
    # shall be used to modify the associated rows. (See example below for events/relays.)
    #
    # Assumes that each detail update item regards an already existing row, with a
    # given 'id' (required).
    # Will do nothing at all if the row is not found.
    #
    # === Example params structure:
    #
    # For GogglesDb::MeetingEventReservation or GogglesDb::MeetingRelayReservation:
    #
    # 'events'|'relays' => [
    #   { id: UPDATED_ROW_ID_1, accepted: true|false, ... },
    #   { id: UPDATED_ROW_ID_2, ... },
    #   ...
    # ]
    def update_subentity_details(params, detail_key, detail_class)
      params.select { |key, _v| key == detail_key }.fetch(detail_key, []).each do |detail_values|
        detail_row = detail_class.find_by_id(detail_values['id'])
        detail_row&.update!(detail_values.reject { |key, _v| key == 'id' })
      end
    end
  end
end
