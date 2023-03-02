module Idv
  module InPerson
    class ResidentialAddressForm
      include ActiveModel::Model
      include Idv::InPerson::ResidentialAddressValidator

      ATTRIBUTES = %i[residential_state residential_zipcode residential_city residential_address1
                      residential_address2].freeze

      attr_accessor(*ATTRIBUTES)

      # TODO: complete below in another story - data persistence is out of scope for 9002
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
