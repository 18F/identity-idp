module Idv
  module InPerson
    class AddressForm
      include ActiveModel::Model
      include Idv::InPerson::FormAddressValidator

      ATTRIBUTES = %i[state zipcode city address1 address2 same_address_as_id].freeze

      attr_accessor(*ATTRIBUTES)

      def self.model_name
        ActiveModel::Name.new(self, nil, 'InPersonAddress')
      end


    validate :transliterable_check

    def transliterable_check
      result = validator.validate({
        address1: address1,
        address2: address2,
        city: city,
      })

      unless result.nil? || result[:address1].nil?
        errors.add(:address1, result[:address1])
      end

      unless result.nil? || result[:address2].nil?
        errors.add(:address2, result[:address2])
      end

      unless result.nil? || result[:city].nil?
        errors.add(:city, result[:city])
      end
    end

    def validator
      @validator ||= UspsInPersonProofing::EnrollmentValidator.new
    end

      def submit(params)
        consume_params(params)

        FormResponse.new(
          success: valid?,
          errors: errors,
        )
      end

      private

      def consume_params(params)
        params.each do |key, value|
          raise_invalid_address_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
          send("#{key}=", value)
        end
      end

      def raise_invalid_address_parameter_error(key)
        raise ArgumentError, "#{key} is an invalid address attribute"
      end
    end
  end
end
