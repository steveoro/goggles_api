# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for MeetingIndividualResult endpoints.
    class MeetingIndividualResultEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'MeetingIndividualResult ID' }
      expose :meeting_program_id, documentation: { type: 'Integer', desc: 'Associated MeetingProgram ID' }
      expose :team_affiliation_id, documentation: { type: 'Integer', desc: 'Associated TeamAffiliation ID' }
      expose :team_id, documentation: { type: 'Integer', desc: 'Associated Team ID' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :badge_id, documentation: { type: 'Integer', desc: 'Associated Badge ID' }
      expose :rank, documentation: { type: 'Integer', desc: 'Final heat rank (1+)' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Result time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Result time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Result time hundredths of seconds' }
      expose :reaction_time, documentation: { type: 'Float', desc: 'Reaction time' }
      expose :standard_points, documentation: { type: 'Float', desc: 'Score computed using standard rules' }
      expose :meeting_points, documentation: { type: 'Float', desc: 'Score computed with meeting-specific rules' }
      expose :goggle_cup_points, documentation: { type: 'Float', desc: 'GoggleCup score for associated team' }
      expose :team_points, documentation: { type: 'Float', desc: 'Score contributing to team scoring' }
      expose :play_off, documentation: { type: 'Boolean', desc: 'True for play-offs at end of season' }
      expose :out_of_race, documentation: { type: 'Boolean', desc: 'True if result does not concur in rankings' }
      expose :disqualified, documentation: { type: 'Boolean', desc: 'True if swimmer has been disqualified' }
      expose :disqualification_code_type_id, documentation: { type: 'Integer', desc: 'DisqualificationCodeType ID' }
      expose :disqualification_notes, documentation: { type: 'String', desc: 'Disqualification notes' }
      expose :personal_best, documentation: { type: 'Boolean', desc: 'True for latest personal best result' }
      expose :season_type_best, documentation: { type: 'Boolean', desc: 'True for latest seasonal best result' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
