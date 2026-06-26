# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingEvent endpoints.
    class MeetingEventEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingEvent ID' }
      expose :meeting_session_id, documentation: { type: 'Integer', desc: 'Associated MeetingSession ID' }
      expose :event_type_id, documentation: { type: 'Integer', desc: 'Associated EventType ID' }
      expose :heat_type_id, documentation: { type: 'Integer', desc: 'Associated HeatType ID' }
      expose :event_order, documentation: { type: 'Integer', desc: 'Ordinal number of this event' }
      expose :begin_time, documentation: { type: 'String', desc: 'Begin time for this event' }
      expose :out_of_race, documentation: { type: 'Boolean', desc: 'True if event does not concur in rankings' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if fields were filled by data-import' }
      expose :notes, documentation: { type: 'String', desc: 'Free notes about this event' }
      expose :split_gender_start_list, documentation: { type: 'Boolean', desc: 'True if event splits gender' }
      expose :split_category_start_list, documentation: { type: 'Boolean', desc: 'True if event splits category' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
