# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for TeamAffiliation endpoints.
    class TeamAffiliationEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'TeamAffiliation ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :name, documentation: { type: 'String', desc: 'Name as it appears in the registration roster' }
      expose :number, documentation: { type: 'String', desc: 'Enrollment or registration badge number' }
      expose :compute_gogglecup, documentation: { type: 'Boolean', desc: 'True when GoggleCup has to be computed' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if autofilled by data-import' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
