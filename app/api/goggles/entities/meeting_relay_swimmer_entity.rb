# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingRelaySwimmer endpoints.
    class MeetingRelaySwimmerEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingRelaySwimmer ID' }
      expose :meeting_relay_result_id, documentation: { type: 'Integer', desc: 'Associated MeetingRelayResult ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :badge_id, documentation: { type: 'Integer', desc: 'Associated Badge ID' }
      expose :stroke_type_id, documentation: { type: 'Integer', desc: 'Associated StrokeType ID' }
      expose :relay_order, documentation: { type: 'Integer', desc: 'Swimmer ordering inside relay (starting position)' }
      expose :reaction_time, documentation: { type: 'Float', desc: 'Reaction time' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Lap time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Lap time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Lap time hundredths of seconds' }
      expose :length_in_meters, documentation: { type: 'Integer', desc: 'Relay lap length in meters' }
      expose :minutes_from_start, documentation: { type: 'Integer', desc: 'Overall minutes from heat start' }
      expose :seconds_from_start, documentation: { type: 'Integer', desc: 'Overall seconds from heat start' }
      expose :hundredths_from_start, documentation: { type: 'Integer', desc: 'Overall hundredths from heat start' }
      expose :relay_laps_count, documentation: { type: 'Integer', desc: 'Count of relay laps' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
