# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for AdminGrant endpoints.
    class AdminGrantEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'AdminGrant ID' }
      expose :entity, documentation: { type: 'String', desc: 'Entity name (model name without GogglesDb:: prefix)' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
