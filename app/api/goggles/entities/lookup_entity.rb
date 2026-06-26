# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Lookup endpoint responses.
    class LookupEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Lookup entry ID' }
      expose :code, documentation: { type: 'String', desc: 'Short code' }
      expose :label, documentation: { type: 'String', desc: 'Short label' }
      expose :long_label, documentation: { type: 'String', desc: 'Full descriptive label' }
      expose :alt_label, documentation: { type: 'String', desc: 'Alternative label' }
    end
  end
end
