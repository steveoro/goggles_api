# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for CategoryType endpoints.
    class CategoryTypeEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'CategoryType ID' }
      expose :season_id, documentation: { type: 'Integer', desc: 'Associated Season ID' }
      expose :code, documentation: { type: 'String', desc: 'Internal code' }
      expose :federation_code, documentation: { type: 'String', desc: 'Federation code' }
      expose :description, documentation: { type: 'String', desc: 'Category description' }
      expose :short_name, documentation: { type: 'String', desc: 'Short category name' }
      expose :group_name, documentation: { type: 'String', desc: 'Category group name' }
      expose :age_begin, documentation: { type: 'Integer', desc: 'Age group start' }
      expose :age_end, documentation: { type: 'Integer', desc: 'Age group end' }
      expose :relay, documentation: { type: 'Boolean', desc: 'True for relay categories' }
      expose :out_of_race, documentation: { type: 'Boolean', desc: 'True if not concurring in overall ranking' }
      expose :undivided, documentation: { type: 'Boolean', desc: 'True for categories without gender splitting' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
