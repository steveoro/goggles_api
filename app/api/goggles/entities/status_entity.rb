# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for status endpoint.
    class StatusEntity < BaseEntity
      expose :msg, documentation: { type: 'String', desc: 'Current service status message' }
      expose :version, documentation: { type: 'String', desc: 'Current application full version' }
    end
  end
end
