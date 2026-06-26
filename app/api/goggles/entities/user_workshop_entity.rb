# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for UserWorkshop endpoints.
    class UserWorkshopEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'UserWorkshop ID' }
      expose :code, documentation: { type: 'String', desc: 'Workshop code-name' }
      expose :description, documentation: { type: 'String', desc: 'Displayed Workshop description' }
      expose :header_date, format_with: :date_only,
                           documentation: { type: 'String', desc: 'Header date (YYYY-MM-DD)' }
      expose :header_year, documentation: { type: 'String', desc: 'Header year (YYYY)' }
      expose :edition, documentation: { type: 'Integer', desc: 'Edition number' }
      expose :edition_type_id, documentation: { type: 'Integer', desc: 'EditionType ID' }
      expose :timing_type_id, documentation: { type: 'Integer', desc: 'TimingType ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'User registering this information' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Organizing Team ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Season ID' }
      expose :swimming_pool_id, documentation: { type: 'Integer', desc: 'SwimmingPool ID (venue)' }
      expose :notes, documentation: { type: 'String', desc: 'Additional notes' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if autofilled by data-import' }
      expose :off_season, documentation: { type: 'Boolean', desc: 'True if workshop does not concur in season scoring' }
      expose :confirmed, documentation: { type: 'Boolean', desc: 'True if workshop has been confirmed' }
      expose :cancelled, documentation: { type: 'Boolean', desc: 'True if workshop has been cancelled' }
      expose :pb_acquired, documentation: { type: 'Boolean', desc: 'True if personal-best timings have been computed' }
      expose :read_only, documentation: { type: 'Boolean', desc: 'True to disable further editing' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
