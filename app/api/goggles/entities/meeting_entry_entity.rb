# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingEntry endpoints.
    class MeetingEntryEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingEntry ID' }
      expose :meeting_program_id, documentation: { type: 'Integer', desc: 'Associated MeetingProgram ID' }
      expose :team_affiliation_id, documentation: { type: 'Integer', desc: 'Associated TeamAffiliation ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :badge_id, documentation: { type: 'Integer', desc: 'Associated Badge ID' }
      expose :entry_time_type_id, documentation: { type: 'Integer', desc: 'Associated EntryTimeType ID' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Entry timing minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Entry timing seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Entry timing hundredths of seconds' }
      expose :no_time, documentation: { type: 'Boolean', desc: 'True for entries with unspecified timing' }
      expose :start_list_number, documentation: { type: 'Integer', desc: 'Start list number' }
      expose :lane_number, documentation: { type: 'Integer', desc: 'Lane number' }
      expose :heat_number, documentation: { type: 'Integer', desc: 'Heat number' }
      expose :heat_arrival_order, documentation: { type: 'Integer', desc: 'Heat arrival order' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
