# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingReservation endpoints.
    class MeetingReservationEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingReservation ID' }
      expose :meeting_id, documentation: { type: 'Integer', desc: 'Associated Meeting ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :badge_id, documentation: { type: 'Integer', desc: 'Associated Badge ID' }
      expose :notes, documentation: { type: 'String', desc: 'Additional free notes' }
      expose :not_coming, documentation: { type: 'Boolean', desc: 'True if swimmer is not attending' }
      expose :confirmed, documentation: { type: 'Boolean', desc: 'True if swimmer has confirmed enrolling/presence' }
      expose :payed, documentation: { type: 'Boolean', desc: 'True if reservation has been paid' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
