# frozen_string_literal: true

module Goggles
  module Entities
    # Base class for all Grape::Entity classes in this API.
    class BaseEntity < Grape::Entity
      format_with(:iso_timestamp) { |dt| dt&.iso8601 }
      format_with(:date_only) { |d| d&.strftime('%Y-%m-%d') }
    end
  end
end
