# frozen_string_literal: true

module Pii
  module AddressValidator
    extend ActiveSupport::Concern

    REQUIRED_ADDRESS_ATTRS = %i[address1 city state zip_code].freeze
    ADDRESS_ATTRS = (REQUIRED_ADDRESS_ATTRS + %i[address2]).freeze

    included do
      validates_presence_of(*REQUIRED_ADDRESS_ATTRS, message: 'cannot be blank')
      validates_format_of :zip_code, with: /\A\d{5}(-?\d{4})?\z/, allow_blank: true
      validates :state, inclusion: { in: Idp::Constants::STATE_AND_TERRITORY_CODES,
                                     message: 'is not a valid state code' }
    end
  end
end
