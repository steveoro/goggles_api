# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for RelayLap endpoints.
    class RelayLapEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'RelayLap ID' }
      expose :meeting_relay_result_id, documentation: { type: 'Integer', desc: 'Associated MeetingRelayResult ID' }
      expose :meeting_relay_swimmer_id, documentation: { type: 'Integer', desc: 'Associated MeetingRelaySwimmer ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :reaction_time, documentation: { type: 'Float', desc: 'Reaction time' }
      expose :minutes, documentation: { type: 'Integer', desc: 'RelayLap time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'RelayLap time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'RelayLap time hundredths of seconds' }
      expose :length_in_meters, documentation: { type: 'Integer', desc: 'RelayLap length in meters' }
      expose :stroke_cycles, documentation: { type: 'Integer', desc: 'RelayLap overall stroke cycles' }
      expose :breath_cycles, documentation: { type: 'Integer', desc: 'RelayLap overall breath cycles' }
      expose :position, documentation: { type: 'Integer', desc: 'Heat position at the end of the relay_lap' }
      expose :minutes_from_start, documentation: { type: 'Integer', desc: 'Overall minutes from heat start' }
      expose :seconds_from_start, documentation: { type: 'Integer', desc: 'Overall seconds from heat start' }
      expose :hundredths_from_start, documentation: { type: 'Integer', desc: 'Overall hundredths from heat start' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
