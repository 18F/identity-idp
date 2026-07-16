# frozen_string_literal: true

module Idv
  module ProofingAgent
    module PassportValidator
      extend ActiveSupport::Concern

      REQUIRED_PASSPORT_ATTRS = %i[mrz issuing_country_code].freeze
      OPTIONAL_PASSPORT_ATTRS = %i[expiration_date issue_date].freeze
      PASSPORT_ATTRS = (REQUIRED_PASSPORT_ATTRS + OPTIONAL_PASSPORT_ATTRS).freeze

      included do
        validates_presence_of(*REQUIRED_PASSPORT_ATTRS, message: 'cannot be blank')
        validates :issuing_country_code,
                  inclusion: { in: Idp::Constants::SUPPORTED_PASSPORT_ISSUING_COUNTRY_CODES,
                               message: 'is not a valid issuing country code' }
        validates_with UspsInPersonProofing::DateValidator,
                       attributes: [:expiration_date],
                       if: -> { expiration_date.present? },
                       greater_than: ->(_rec) do
                         Time.zone.today.to_date + 2.days
                       end,
                       message: 'is expired, or near expiration'
      end
    end
  end
end
