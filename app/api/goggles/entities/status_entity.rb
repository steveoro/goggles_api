# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for status endpoint.
    class StatusEntity < BaseEntity
      expose :msg, documentation: { type: 'String', desc: 'Current service status message' }
      expose :version, documentation: { type: 'String', desc: 'Current application full version' }
      expose :environment, documentation: { type: 'String', desc: "Rails environment the API is running in (e.g. 'production', 'development')" }
      expose :capabilities, documentation: {
        type: 'String', is_array: true,
        desc: "Supported feature flags: 'iq_batch_outcome' (batch SQL import-queue rows report applied/failed + error text " \
              "and their data file details; a failed row blocks the later ones), 'iq_batch_filters' (GET import_queues " \
              "'batch_sql' & 'done' filters), 'db_fingerprint' (GET tools/db_fingerprint)"
      }
    end
  end
end
