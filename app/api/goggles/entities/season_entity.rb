# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Season endpoints.
    class SeasonEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Season ID' }
      expose :description, documentation: { type: 'String', desc: 'Verbose description' }
      expose :begin_date, format_with: :date_only,
                          documentation: { type: 'String', desc: 'First day of the Season (YYYY-MM-DD)' }
      expose :end_date, format_with: :date_only,
                        documentation: { type: 'String', desc: 'Last day of the Season (YYYY-MM-DD)' }
      expose :season_type_id, documentation: { type: 'Integer', desc: 'Associated SeasonType ID' }
      expose :header_year, documentation: { type: 'String', desc: 'Referenced year(s) (YYYY or YYYY/YYYY+1)' }
      expose :edition, documentation: { type: 'Integer', desc: 'Edition number' }
      expose :edition_type_id, documentation: { type: 'Integer', desc: 'Associated EditionType ID' }
      expose :timing_type_id, documentation: { type: 'Integer', desc: 'Associated TimingType ID' }
      expose :rules, documentation: { type: 'String', desc: 'Season rules' }
      expose :individual_rank, documentation: { type: 'Boolean', desc: 'True if individual rankings are supported' }
      expose :badge_fee, documentation: { type: 'Float', desc: 'Base registration/badge fee' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
