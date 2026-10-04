# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for Training (Creative trainings photo gallery) endpoints.
    #
    # Computed attachment fields returned alongside these columns by the endpoints:
    # - +picture_filename+: original uploaded filename (stored in the AS blob)
    # - +image_path+:       permanent signed path to the full-size image (relative to API base URL)
    # - +image_thumb_path+: permanent signed path to a resized variant
    # - +image_missing+:    true when the blob exists but its file is missing from storage
    class TrainingEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'Training ID' }
      expose :title, documentation: { type: 'String', desc: 'Auto-generated title (<iso_date> <created_by>)' }
      expose :training_date, format_with: :iso_timestamp,
                             documentation: { type: 'String', desc: 'Training session date (ISO8601)' }
      expose :training_by, documentation: { type: 'String', desc: 'Who ran the training' }
      expose :created_by, documentation: { type: 'String', desc: 'Who created the picture/workout' }
      expose :swimmer_id, documentation: { type: 'Integer', desc: 'Associated Swimmer ID (optional)' }
      expose :description, documentation: { type: 'String', desc: 'Text content of the training (optional)' }
      expose :picture_filename, documentation: { type: 'String', desc: 'Original uploaded picture filename' }
      expose :image_path, documentation: { type: 'String', desc: 'Permanent signed path to full-size image' }
      expose :image_thumb_path, documentation: { type: 'String', desc: 'Permanent signed path to image thumbnail variant' }
      expose :image_missing, documentation: { type: 'Boolean', desc: 'True when the image file is missing from storage' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
