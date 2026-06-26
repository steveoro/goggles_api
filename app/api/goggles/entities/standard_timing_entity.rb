# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for StandardTiming endpoints.
    class StandardTimingEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'StandardTiming ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :gender_type_id, documentation: { type: 'Integer', desc: 'Associated GenderType ID' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :event_type_id, documentation: { type: 'Integer', desc: 'Associated EventType ID' }
      expose :category_type_id, documentation: { type: 'Integer', desc: 'Associated CategoryType ID' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Minutes value' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Seconds value' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Hundredths of seconds value' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
