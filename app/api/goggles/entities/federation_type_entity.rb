# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for FederationType endpoints.
    class FederationTypeEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'FederationType ID' }
      expose :code, documentation: { type: 'String', desc: 'Internal federation code' }
      expose :description, documentation: { type: 'String', desc: 'Federation type description' }
      expose :short_name, documentation: { type: 'String', desc: 'Short federation type name' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
