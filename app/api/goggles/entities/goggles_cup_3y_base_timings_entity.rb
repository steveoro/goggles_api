# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for GogglesCup3yBaseTimings (Scenic view) endpoint.
    class GogglesCup3yBaseTimingsEntity < BaseEntity
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :swimmer_name, documentation: { type: 'String', desc: 'Swimmer complete name' }
      expose :swimmer_year_of_birth, documentation: { type: 'Integer', desc: 'Swimmer year of birth' }
      expose :gender_type_id, documentation: { type: 'Integer', desc: 'Associated GenderType ID' }
      expose :event_type_id, documentation: { type: 'Integer', desc: 'Associated EventType ID' }
      expose :event_type_code, documentation: { type: 'String', desc: 'EventType code' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :pool_type_code, documentation: { type: 'String', desc: 'PoolType code' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :season_header_year, documentation: { type: 'String', desc: 'Season header year' }
      expose :meeting_individual_result_id, documentation: { type: 'Integer', desc: 'Associated MeetingIndividualResult ID (primary key of the view)' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Timing minutes component' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Timing seconds component' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Timing hundredths component' }
      expose :total_hundredths, documentation: { type: 'Integer', desc: 'Total timing in hundredths of a second' }
      expose :meeting_id, documentation: { type: 'Integer', desc: 'Associated Meeting ID' }
      expose :meeting_date, format_with: :date_only,
                            documentation: { type: 'String', desc: 'Meeting date (YYYY-MM-DD)' }
      expose :meeting_name, documentation: { type: 'String', desc: 'Meeting description' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :team_name, documentation: { type: 'String', desc: 'Team name' }
    end
  end
end
