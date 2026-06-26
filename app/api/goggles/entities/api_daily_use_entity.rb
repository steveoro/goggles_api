# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for APIDailyUse endpoints.
    class APIDailyUseEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'APIDailyUse ID' }
      expose :route, documentation: { type: 'String', desc: 'Base route of the API call counter' }
      expose :day, format_with: :date_only,
                   documentation: { type: 'String', desc: 'Date (day) for the API usage counter (YYYY-MM-DD)' }
      expose :count, documentation: { type: 'Integer', desc: 'Counter value' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
