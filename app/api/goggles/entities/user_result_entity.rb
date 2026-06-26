# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for UserResult endpoints.
    class UserResultEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'UserResult ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID (creator/recorder)' }
      expose :user_workshop_id, documentation: { type: 'Integer', desc: 'Associated UserWorkshop ID' }
      expose :event_date, format_with: :date_only,
                          documentation: { type: 'String', desc: 'Date for the event/result (YYYY-MM-DD)' }
      expose :description, documentation: { type: 'String', desc: 'Description for this event/result' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :swimming_pool_id, documentation: { type: 'Integer', desc: 'Associated SwimmingPool ID' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :category_type_id, documentation: { type: 'Integer', desc: 'Associated CategoryType ID' }
      expose :event_type_id, documentation: { type: 'Integer', desc: 'Associated EventType ID' }
      expose :standard_timing_id, documentation: { type: 'Integer', desc: 'Associated StandardTiming ID' }
      expose :reaction_time, documentation: { type: 'Float', desc: 'Reaction time' }
      expose :minutes, documentation: { type: 'Integer', desc: 'Result time minutes' }
      expose :seconds, documentation: { type: 'Integer', desc: 'Result time seconds' }
      expose :hundredths, documentation: { type: 'Integer', desc: 'Result time hundredths of seconds' }
      expose :standard_points, documentation: { type: 'Float', desc: 'Score computed using standard rules' }
      expose :meeting_points, documentation: { type: 'Float', desc: 'Score computed with meeting-specific rules' }
      expose :rank, documentation: { type: 'Integer', desc: 'Final heat rank (1+)' }
      expose :disqualified, documentation: { type: 'Boolean', desc: 'True if swimmer has been disqualified' }
      expose :disqualification_code_type_id, documentation: { type: 'Integer', desc: 'DisqualificationCodeType ID' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
