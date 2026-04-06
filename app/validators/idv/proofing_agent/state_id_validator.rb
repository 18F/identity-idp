# frozen_string_literal: true

module Idv
  module ProofingAgent
    module StateIdValidator
      extend ActiveSupport::Concern
      include AddressValidator

      REQUIRED_STATE_ID_ATTRS = %i[document_number jurisdiction expiration_date issue_date].freeze
      STATE_ID_ATTRS = (REQUIRED_STATE_ID_ATTRS + AddressValidator::ADDRESS_ATTRS).freeze

      included do
        validates_presence_of(*REQUIRED_STATE_ID_ATTRS, message: 'cannot be blank')
        validates :jurisdiction, inclusion: { in: Idp::Constants::STATE_AND_TERRITORY_CODES,
                                              message: 'is not a valid state code' }
        validates_with UspsInPersonProofing::DateValidator,
                       attributes: [:expiration_date],
                       greater_than_or_equal_to: ->(_rec) do
                         Time.zone.today + 2.days
                       end,
                       message: 'is expired, or near expiration'
      end
    end
  end
end
