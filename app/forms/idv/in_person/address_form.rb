module Idv
  module InPerson
    class AddressForm
      include ActiveModel::Model
      include Idv::InPerson::FormAddressValidator

      ATTRIBUTES = %i[state zipcode city address1 address2 same_address_as_id].freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(capture_secondary_id_enabled:)
        @capture_secondary_id_enabled = capture_secondary_id_enabled
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'InPersonAddress')
      end

      def submit(params)
        consume_params(params)

        validation_success = valid?
        cleaned_errors = errors.dup
        cleaned_errors.delete(:city, :nontransliterable_field)
        cleaned_errors.delete(:address1, :nontransliterable_field)
        cleaned_errors.delete(:address2, :nontransliterable_field)

        FormResponse.new(
          success: validation_success,
          errors: cleaned_errors,
        )
      end

      private

      attr_reader :capture_secondary_id_enabled
      alias_method :capture_secondary_id_enabled?, :capture_secondary_id_enabled

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
