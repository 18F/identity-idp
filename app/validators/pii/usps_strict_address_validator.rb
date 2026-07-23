# frozen_string_literal: true

module Pii
  module UspsStrictAddressValidator
    extend ActiveSupport::Concern
    include Pii::AddressValidator

    included do
      validates :address1, :address2, :city, length: { maximum: 255 }
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
