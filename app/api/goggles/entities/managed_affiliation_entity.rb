# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for ManagedAffiliation (TeamManager) endpoints.
    class ManagedAffiliationEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'ManagedAffiliation ID' }
      expose :team_affiliation_id, documentation: { type: 'Integer', desc: 'Associated TeamAffiliation ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID (Team Manager)' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
