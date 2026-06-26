# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for IndividualRecord endpoints.
    class IndividualRecordEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'IndividualRecord ID' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :event_type_id, documentation: { type: 'Integer', desc: 'Associated EventType ID' }
      expose :category_type_id, documentation: { type: 'Integer', desc: 'Associated CategoryType ID' }
      expose :gender_type_id, documentation: { type: 'Integer', desc: 'Associated GenderType ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :federation_type_id, documentation: { type: 'Integer', desc: 'Associated FederationType ID' }
      expose :meeting_individual_result_id, documentation: { type: 'Integer', desc: 'Associated MIR ID' }
      expose :record_type_id, documentation: { type: 'Integer', desc: 'Associated RecordType ID' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Record time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Record time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Record time hundredths of seconds' }
      expose :team_record, documentation: { type: 'Boolean', desc: 'True if this is a team record' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
