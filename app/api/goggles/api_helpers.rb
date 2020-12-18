# frozen_string_literal: true

module Goggles
  # = APIHelpers module
  #
  #   Wrapper module for helper methods used by the API.
  #
  #   - version:  1.11
  #   - author:   Steve A.
  #   - build:    20201208
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
      authorization.result
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
  end
end
