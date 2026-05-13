# frozen_string_literal: true

module Idv
  module ProofingAgent
    module AddressValidator
      extend ActiveSupport::Concern
      REQUIRED_ADDRESS_ATTRS = %i[address1 city state zip_code].freeze
      ADDRESS_ATTRS = (REQUIRED_ADDRESS_ATTRS + %i[address2]).freeze

      included do
        validates_presence_of(*REQUIRED_ADDRESS_ATTRS, message: 'cannot be blank')
        validates :address1, :address2, :city, length: { maximum: 255 }
        validates_format_of :zip_code, with: /\A\d{5}(-?\d{4})?\z/, allow_blank: true
        validates :state, inclusion: { in: Idp::Constants::STATE_AND_TERRITORY_CODES,
                                       message: 'is not a valid state code' }
        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:city],
                       reject_chars: /[^A-Za-z\-' ]/,
                       message: ->(invalid_chars) do
                         "has invalid characters (#{invalid_chars.join(', ')})"
                       end
        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:address1, :address2],
                       reject_chars: /[^A-Za-z0-9\-' .\/#]/,
                       message: ->(invalid_chars) do
                         "has invalid characters (#{invalid_chars.join(', ')})"
                       end
      end
    end
  end
end
