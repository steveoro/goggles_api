# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for the DB fingerprint tool endpoint (GET tools/db_fingerprint).
    class DbFingerprintEntity < BaseEntity
      expose :environment, documentation: { type: 'String', desc: "Rails environment the API is running in (e.g. 'production')" }
      expose :generated_at, documentation: { type: 'String', desc: 'When the values were computed (ISO8601, UTC; cached up to 60 s)' }
      expose :schema_version, documentation: { type: 'String', desc: 'Current DB schema migration version' }
      expose :db_version, documentation: { type: 'String', desc: 'DB data version stored in the versioning parameter row' }
      expose :import_queue, documentation: {
        type: 'Hash',
        desc: "Import queue summary: 'next_id' (next auto-increment ID), 'batch_queued' (unfinished batch SQL rows " \
              "without errors: queued or running), 'batch_failed' (unfinished batch SQL rows with errors: blocking the queue)"
      }
      expose :tables, documentation: {
        type: 'Hash',
        desc: "Hash keyed by table name: { 'count', 'max_id', 'max_updated_at' (ISO8601, UTC) } in full mode, " \
              "just { 'max_id' } in light mode"
      }
    end
  end
end
