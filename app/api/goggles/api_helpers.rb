# frozen_string_literal: true

module Goggles
  # = APIHelpers module
  #
  #   Wrapper module for helper methods used by the API.
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201002
  #
  module APIHelpers
    extend Grape::API::Helpers

    params :period do
      optional :start_date
      optional :end_date
    end

    params :pagination do
      optional :page,     type: Integer
      optional :per_page, type: Integer
    end
  end
end
