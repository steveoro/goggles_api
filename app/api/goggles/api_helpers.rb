# frozen_string_literal: true

module Goggles
  # = APIHelpers module
  #
  #   Wrapper module for helper methods used by the API.
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
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

    # Yields the 'JWT invalid' error if the session token is not valid anymore; it does nothing otherwise.
    def check_jwt_session
      !CmdAuthorizeAPIRequest.new(headers).call.success? &&
        error!(I18n.t('api.message.unauthorized'), 401, 'X-Error-Detail' => I18n.t('api.message.jwt.invalid'))
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
      filtering
    end

    # Similarly to filtering_hash_for, returns a where-condition Hash but based on 'LIKE %?%' matches
    # instead of perfect matches, given the specified field list and the current params Hash.
    # Returns nil when no condition is appliable.
    #
    # Assumes a 1:1 mapping and same-named columns for both field_list (which are the column names)
    # and the params.keys names.
    def filtering_like_for(params, field_list)
      like_condition = field_list.dup.keep_if { |field_name| params.key?(field_name) }
                                 .map { |field_name| "(#{field_name} LIKE ?)" }.join(' AND ')
      # TODO: SANITIZE THE VALUES!
      field_values = params.dup.keep_if { |key, _v| field_list.include?(key) }
                           .values.map { |value| "%#{value}%" }
      [like_condition, field_values].flatten unless field_values.empty?
    end
  end
end
