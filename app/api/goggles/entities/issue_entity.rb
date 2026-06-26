# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Issue endpoints.
    class IssueEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Issue ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :code, documentation: { type: 'String', desc: 'Issue code type (max 3 chars)' }
      expose :req, documentation: { type: 'String', desc: 'Parsable JSON request with required parameters' }
      expose :priority, documentation: { type: 'Integer', desc: 'Request priority (0..3)' }
      expose :status, documentation: { type: 'Integer', desc: 'Request status (processable: 0..3, solved/rejected: 4..6)' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
