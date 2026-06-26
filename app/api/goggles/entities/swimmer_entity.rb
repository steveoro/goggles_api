# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Swimmer endpoints.
    class SwimmerEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Swimmer ID' }
      expose :complete_name, documentation: { type: 'String', desc: 'Complete name as it appears from public rankings' }
      expose :first_name, documentation: { type: 'String', desc: 'First name' }
      expose :last_name, documentation: { type: 'String', desc: 'Last name' }
      expose :nickname, documentation: { type: 'String', desc: 'Nickname' }
      expose :year_of_birth, documentation: { type: 'Integer', desc: 'Year of birth (may be guessed)' }
      expose :year_guessed, documentation: { type: 'Boolean', desc: 'True when year of birth has been deduced' }
      expose :gender_type_id, documentation: { type: 'Integer', desc: 'Associated GenderType ID' }
      expose :associated_user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :phone_mobile, documentation: { type: 'String', desc: 'Mobile phone number' }
      expose :phone_number, documentation: { type: 'String', desc: 'Phone number' }
      expose :e_mail, documentation: { type: 'String', desc: 'Email address' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
