# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for badge endpoint.
    class BadgeEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Badge ID' }
      expose :number, documentation: { type: 'String', desc: 'Badge number/code' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated swimmer ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated team ID' }
      expose :team_affiliation_id, documentation: { type: 'Integer', desc: 'Associated team affiliation ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated season ID' }
      expose :category_type_id, documentation: { type: 'Integer', desc: 'Associated category type ID' }
      expose :entry_time_type_id, documentation: { type: 'Integer', desc: 'Associated entry time type ID' }
      expose :off_gogglecup, documentation: { type: 'Boolean', desc: 'GoggleCup eligibility flag' }
      expose :fees_due, documentation: { type: 'Boolean', desc: 'Meeting fees due flag' }
      expose :badge_due, documentation: { type: 'Boolean', desc: 'Badge fees due flag' }
      expose :relays_due, documentation: { type: 'Boolean', desc: 'Relay fees due flag' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
