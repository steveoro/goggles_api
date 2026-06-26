# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for SeasonType endpoints.
    class SeasonTypeEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'SeasonType ID' }
      expose :code, documentation: { type: 'String', desc: 'Internal code' }
      expose :description, documentation: { type: 'String', desc: 'Season type description' }
      expose :short_name, documentation: { type: 'String', desc: 'Short season type name' }
      expose :federation_type_id, documentation: { type: 'Integer', desc: 'Associated FederationType ID' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
