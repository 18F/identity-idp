module Idv
  class InPersonProofingAddressForm
    include ActiveModel::Model

    def initialize(pii)
      @pii = pii
    end

    def submit(params)
      non_address_params = params.except(*AddressForm::ATTRIBUTES)
      address_params = params.extract!(*AddressForm::ATTRIBUTES)
      address_response = AddressForm.new(@pii).submit(address_params)

      consume_params(non_address_params)

      FormResponse.new(
        success: valid? && address_response.success?,
        errors: address_response.errors.merge(errors.to_hash),
        extra: address_response.extra,
      )
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_address_parameter_error(key) unless key.to_sym == :same_address_as_id
        send("#{key}=", value)
      end
    end

    def raise_invalid_address_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid address attribute"
    end
  end
end
