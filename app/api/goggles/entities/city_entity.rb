# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for City endpoints.
    class CityEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'City ID' }
      expose :name, documentation: { type: 'String', desc: 'City name' }
      expose :country_code, documentation: { type: 'String', desc: 'Country code (2 chars)' }
      expose :country, documentation: { type: 'String', desc: 'Country name' }
      expose :area, documentation: { type: 'String', desc: 'Area or Region/Division name' }
      expose :zip, documentation: { type: 'String', desc: 'ZIP/CAP or Postal code' }
      expose :latitude, documentation: { type: 'String', desc: 'City latitude' }
      expose :longitude, documentation: { type: 'String', desc: 'City longitude' }
      expose :plus_code, documentation: { type: 'String', desc: 'Plus code (geocode)' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
