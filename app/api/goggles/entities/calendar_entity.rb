# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Calendar endpoints.
    class CalendarEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Calendar ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :meeting_id, documentation: { type: 'Integer', desc: 'Associated Meeting ID (set after import)' }
      expose :scheduled_date, documentation: { type: 'String', desc: 'Schedule date or dates (DD1-DD2)' }
      expose :month, documentation: { type: 'String', desc: 'Month in 3-char format (MMM)' }
      expose :year, documentation: { type: 'String', desc: 'Scheduled year (YYYY)' }
      expose :meeting_code, documentation: { type: 'String', desc: 'Internal Meeting code-name' }
      expose :meeting_name, documentation: { type: 'String', desc: 'Meeting name' }
      expose :meeting_place, documentation: { type: 'String', desc: 'Meeting place or city name' }
      expose :manifest_code, documentation: { type: 'String', desc: 'Code to retrieve manifest from source URL' }
      expose :startlist_code, documentation: { type: 'String', desc: 'Code to retrieve startlist from source URL' }
      expose :results_code, documentation: { type: 'String', desc: 'Code to retrieve results from source URL' }
      expose :results_link, documentation: { type: 'String', desc: 'Direct URL to results list' }
      expose :startlist_link, documentation: { type: 'String', desc: 'Direct URL to startlist' }
      expose :manifest_link, documentation: { type: 'String', desc: 'Direct URL to manifest' }
      expose :manifest, documentation: { type: 'String', desc: 'Full manifest page text or URL' }
      expose :name_import_text, documentation: { type: 'String', desc: 'Extracted meeting name from manifest' }
      expose :organization_import_text, documentation: { type: 'String', desc: 'Extracted organizing team from manifest' }
      expose :place_import_text, documentation: { type: 'String', desc: 'Extracted meeting place from manifest' }
      expose :dates_import_text, documentation: { type: 'String', desc: 'Extracted meeting dates from manifest' }
      expose :program_import_text, documentation: { type: 'String', desc: 'Extracted meeting program from manifest' }
      expose :cancelled, documentation: { type: 'Boolean', desc: 'True if the Meeting has been cancelled' }
      expose :read_only, documentation: { type: 'Boolean', desc: 'True to disable further editing by data-import' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
