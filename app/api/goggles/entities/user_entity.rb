# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for User endpoints.
    class UserEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'User ID' }
      expose :name, documentation: { type: 'String', desc: 'User name' }
      expose :first_name, documentation: { type: 'String', desc: 'First name' }
      expose :last_name, documentation: { type: 'String', desc: 'Last name' }
      expose :description, documentation: { type: 'String', desc: 'User description (usually first_name + last_name)' }
      expose :email, documentation: { type: 'String', desc: 'Email address' }
      expose :year_of_birth, documentation: { type: 'Integer', desc: 'Year of birth' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID' }
      expose :swimmer_level_type_id, documentation: { type: 'Integer', desc: 'SwimmerLevelType ID' }
      expose :coach_level_type_id, documentation: { type: 'Integer', desc: 'CoachLevelType ID' }
      expose :active, documentation: { type: 'Boolean', desc: 'True if account is active' }
      expose :avatar_url, documentation: { type: 'String', desc: 'Avatar image URL' }
      expose :outstanding_goggle_score_bias, documentation: { type: 'Float', desc: 'Goggle score bias' }
      expose :outstanding_standard_score_bias, documentation: { type: 'Float', desc: 'Standard score bias' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
