# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingSession endpoints.
    class MeetingSessionEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingSession ID' }
      expose :meeting_id, documentation: { type: 'Integer', desc: 'Associated Meeting ID' }
      expose :swimming_pool_id, documentation: { type: 'Integer', desc: 'Associated SwimmingPool ID' }
      expose :session_order, documentation: { type: 'Integer', desc: 'Numerical order of the session (1+)' }
      expose :scheduled_date, format_with: :date_only,
                              documentation: { type: 'String', desc: 'Schedule date (YYYY-MM-DD)' }
      expose :warm_up_time, documentation: { type: 'String', desc: 'Warm-up hour (HH:MM)' }
      expose :begin_time, documentation: { type: 'String', desc: 'Event start hour (HH:MM)' }
      expose :description, documentation: { type: 'String', desc: 'Session description' }
      expose :notes, documentation: { type: 'String', desc: 'Free text notes' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if values were autofilled by data-import' }
      expose :day_part_type_id, documentation: { type: 'Integer', desc: 'DayPartType ID (morning, afternoon, evening)' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
