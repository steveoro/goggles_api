# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Lap endpoints.
    class LapEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Lap ID' }
      expose :meeting_individual_result_id, documentation: { type: 'Integer', desc: 'Associated MeetingIndividualResult ID' }
      expose :meeting_program_id, documentation: { type: 'Integer', desc: 'Associated MeetingProgram ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :reaction_time, documentation: { type: 'Float', desc: 'Reaction time' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Lap time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Lap time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Lap time hundredths of seconds' }
      expose :length_in_meters, documentation: { type: 'Integer', desc: 'Lap length in meters' }
      expose :stroke_cycles, documentation: { type: 'Integer', desc: 'Lap overall stroke cycles' }
      expose :underwater_seconds, documentation: { type: 'Integer', desc: 'Time spent underwater on turn/start, seconds' }
      expose :underwater_hundredths, documentation: { type: 'Integer', desc: 'Time spent underwater on turn/start, hundredths' }
      expose :underwater_kicks, documentation: { type: 'Integer', desc: 'Underwater kicks after lap turn/start' }
      expose :breath_cycles, documentation: { type: 'Integer', desc: 'Lap overall breath cycles' }
      expose :position, documentation: { type: 'Integer', desc: 'Heat position at the end of the lap' }
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
