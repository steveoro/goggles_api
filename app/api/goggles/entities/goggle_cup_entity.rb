# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for GoggleCup endpoints.
    class GoggleCupEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'GoggleCup ID' }
      expose :description, documentation: { type: 'String', desc: 'GoggleCup description' }
      expose :season_year, documentation: { type: 'Integer', desc: 'Season year' }
      expose :max_points, documentation: { type: 'Integer', desc: 'Maximum points for the GoggleCup' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :end_date, format_with: :date_only,
                        documentation: { type: 'String', desc: 'End date (YYYY-MM-DD)' }
      expose :team_constrained, documentation: { type: 'Boolean', desc: 'True if the GoggleCup is constrained to the team' }
      expose :swimmers_ids, documentation: { type: 'String', desc: 'Comma-separated list of swimmer IDs (nullable)' }
      expose :ranking_data, documentation: { type: 'String', desc: 'Stringified JSON object with ranking data (nullable)' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
