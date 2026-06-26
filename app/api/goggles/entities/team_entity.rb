# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Team endpoints.
    class TeamEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Team ID' }
      expose :name, documentation: { type: 'String', desc: 'Team name' }
      expose :editable_name, documentation: { type: 'String', desc: 'Team name as edited by Team Manager' }
      expose :city_id, documentation: { type: 'Integer', desc: 'Associated City ID' }
      expose :address, documentation: { type: 'String', desc: 'Team HQ address' }
      expose :zip, documentation: { type: 'String', desc: 'Team HQ zip code' }
      expose :phone_mobile, documentation: { type: 'String', desc: 'HQ mobile or secondary phone' }
      expose :phone_number, documentation: { type: 'String', desc: 'HQ official phone number' }
      expose :fax_number, documentation: { type: 'String', desc: 'HQ fax number' }
      expose :e_mail, documentation: { type: 'String', desc: 'Official contact e-mail' }
      expose :contact_name, documentation: { type: 'String', desc: 'Official contact name' }
      expose :notes, documentation: { type: 'String', desc: 'Additional notes by Team Manager' }
      expose :home_page_url, documentation: { type: 'String', desc: 'Team Website URL' }
      expose :name_variations, documentation: { type: 'String', desc: 'Team name variations for matching' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
