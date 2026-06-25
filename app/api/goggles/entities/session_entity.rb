# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for session endpoint.
    class SessionEntity < BaseEntity
      expose :msg, documentation: { type: 'String', desc: 'Result message' }
      expose :jwt, documentation: { type: 'String', desc: 'Generated JWT session token' }
    end
  end
end
