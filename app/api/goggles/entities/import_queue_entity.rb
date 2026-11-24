# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for ImportQueue endpoints (documentation only: the endpoints render GogglesDb::ImportQueue#to_hash).
    #
    # Batch SQL rows outcome encoding:
    # - queued  => done: false, process_runs: 0, error_messages: nil
    # - running => done: false, process_runs > 0, error_messages: nil
    # - applied => done: true, error_messages: nil
    # - failed  => done: false, error_messages present (blocks the later batch rows until retried or deleted)
    class ImportQueueEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'ImportQueue ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :process_runs, documentation: { type: 'Integer', desc: 'Current processed depth' }
      expose :request_data, documentation: { type: 'String', desc: 'Parsable JSON with requested entities and their state' }
      expose :solved_data, documentation: { type: 'String', desc: 'Parsable JSON with solved entities and their IDs' }
      expose :done, documentation: { type: 'Boolean', desc: 'True if request is deletable (processed & solved)' }
      expose :uid, documentation: { type: 'String', desc: 'Queue UID' }
      expose :bindings_left_count, documentation: { type: 'Integer', desc: 'Remaining bindings count' }
      expose :bindings_left_list, documentation: { type: 'String', desc: 'Remaining bindings list' }
      expose :error_messages, documentation: {
        type: 'String', desc: 'Error messages; for batch SQL rows, the DB client error output when the script failed (nil otherwise)'
      }
      expose :import_queue_id, documentation: { type: 'Integer', desc: 'Parent ImportQueue ID' }
      expose :batch_sql, documentation: { type: 'Boolean', desc: 'True if this is a SQL batch import' }
      # (Keys added only for batch SQL rows, all nil when no file is attached:)
      expose :data_file_name, documentation: { type: 'String', desc: 'Batch SQL rows only: file name of the attached SQL batch file' }
      expose :data_file_checksum, documentation: { type: 'String', desc: 'Batch SQL rows only: base64 MD5 digest of the attached file (ActiveStorage checksum)' }
      expose :data_file_byte_size, documentation: { type: 'Integer', desc: 'Batch SQL rows only: size in bytes of the attached file' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
