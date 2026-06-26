# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingProgram endpoints.
    class MeetingProgramEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingProgram ID' }
      expose :meeting_event_id, documentation: { type: 'Integer', desc: 'Associated MeetingEvent ID' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :category_type_id, documentation: { type: 'Integer', desc: 'Associated CategoryType ID' }
      expose :gender_type_id, documentation: { type: 'Integer', desc: 'Associated GenderType ID' }
      expose :standard_timing_id, documentation: { type: 'Integer', desc: 'Associated StandardTiming ID' }
      expose :event_order, documentation: { type: 'Integer', desc: 'Ordinal number of this program' }
      expose :begin_time, documentation: { type: 'String', desc: 'Begin time for this program' }
      expose :out_of_race, documentation: { type: 'Boolean', desc: 'True if program does not concur in rankings' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if fields were filled by data-import' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
