# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Meeting endpoints.
    class MeetingEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Meeting ID' }
      expose :code, documentation: { type: 'String', desc: 'Meeting code-name' }
      expose :description, documentation: { type: 'String', desc: 'Displayed Meeting description' }
      expose :header_date, format_with: :date_only,
                           documentation: { type: 'String', desc: 'Header (main) date (YYYY-MM-DD)' }
      expose :header_year, documentation: { type: 'String', desc: 'Header year (YYYY)' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :edition, documentation: { type: 'Integer', desc: 'Edition number' }
      expose :edition_type_id, documentation: { type: 'Integer', desc: 'EditionType ID' }
      expose :timing_type_id, documentation: { type: 'Integer', desc: 'TimingType ID' }
      expose :home_team_id, documentation: { type: 'Integer', desc: 'Organizing Team ID' }
      expose :entry_deadline, format_with: :date_only,
                              documentation: { type: 'String', desc: 'Entry deadline (YYYY-MM-DD)' }
      expose :warm_up_pool, documentation: { type: 'Boolean', desc: 'True if warm-up pool available' }
      expose :allows_under25, documentation: { type: 'Boolean', desc: 'True if under-25 can compete' }
      expose :reference_phone, documentation: { type: 'String', desc: 'Contact phone' }
      expose :reference_e_mail, documentation: { type: 'String', desc: 'Contact e-mail' }
      expose :reference_name, documentation: { type: 'String', desc: 'Contact name' }
      expose :max_individual_events, documentation: { type: 'Integer', desc: 'Max individual events per session' }
      expose :max_individual_events_per_session, documentation: { type: 'Integer', desc: 'Max individual events per session' }
      expose :meeting_fee, documentation: { type: 'Integer', desc: 'Enrollment/registration cost (Euros)' }
      expose :event_fee, documentation: { type: 'Integer', desc: 'Individual event cost (Euros)' }
      expose :relay_fee, documentation: { type: 'Integer', desc: 'Relay event cost (Euros)' }
      expose :notes, documentation: { type: 'String', desc: 'Additional notes' }
      expose :manifest_body, documentation: { type: 'String', desc: 'Meeting manifest body (text or html)' }
      expose :manifest, documentation: { type: 'Boolean', desc: 'True if manifest is available/published' }
      expose :startlist, documentation: { type: 'Boolean', desc: 'True if startlist has been published' }
      expose :results_acquired, documentation: { type: 'Boolean', desc: 'True if results have been acquired' }
      expose :confirmed, documentation: { type: 'Boolean', desc: 'True if Meeting has been confirmed' }
      expose :cancelled, documentation: { type: 'Boolean', desc: 'True if Meeting has been cancelled' }
      expose :off_season, documentation: { type: 'Boolean', desc: 'True if Meeting does not concur in season scoring' }
      expose :autofilled, documentation: { type: 'Boolean', desc: 'True if fields were filled by data-import' }
      expose :tweeted, documentation: { type: 'Boolean', desc: 'True if result link has been tweeted' }
      expose :posted, documentation: { type: 'Boolean', desc: 'True if result link has been posted on social media' }
      expose :pb_acquired, documentation: { type: 'Boolean', desc: 'True if personal-best timings have been computed' }
      expose :read_only, documentation: { type: 'Boolean', desc: 'True to disable editing by data-import' }
      expose :individual_score_computation_type_id, documentation: { type: 'Integer', desc: 'IndividualScoreComputationType ID' }
      expose :relay_score_computation_type_id, documentation: { type: 'Integer', desc: 'RelayScoreComputationType ID' }
      expose :team_score_computation_type_id, documentation: { type: 'Integer', desc: 'TeamScoreComputationType ID' }
      expose :meeting_score_computation_type_id, documentation: { type: 'Integer', desc: 'MeetingScoreComputationType ID' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
