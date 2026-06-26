# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for BadgePayment endpoints.
    class BadgePaymentEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'BadgePayment ID' }
      expose :amount, documentation: { type: 'Float', desc: 'Payment amount' }
      expose :payment_date, format_with: :date_only,
                            documentation: { type: 'String', desc: 'Payment date (YYYY-MM-DD)' }
      expose :notes, documentation: { type: 'String', desc: 'Free text notes' }
      expose :manual, documentation: { type: 'Boolean', desc: 'True for cash payments made by hand' }
      expose :badge_id, documentation: { type: 'Integer', desc: 'Associated Badge ID' }
      expose :user_id, documentation: { type: 'Integer', desc: 'Associated User ID' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end
