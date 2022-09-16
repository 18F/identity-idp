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
