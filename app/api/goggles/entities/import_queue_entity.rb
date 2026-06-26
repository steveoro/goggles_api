# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for ImportQueue endpoints.
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
      expose :error_messages, documentation: { type: 'String', desc: 'Error messages' }
      expose :import_queue_id, documentation: { type: 'Integer', desc: 'Parent ImportQueue ID' }
      expose :batch_sql, documentation: { type: 'Boolean', desc: 'True if this is a SQL batch import' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
