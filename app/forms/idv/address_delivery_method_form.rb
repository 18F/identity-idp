module Idv
  class AddressDeliveryMethodForm
    attr_accessor :address_delivery_method

    def submit(address_delivery_method: '')
      self.address_delivery_method = address_delivery_method

      FormResponse.new(success: valid_address_delivery_method?, errors: {})
    end

    private

    def valid_address_delivery_method?
      %w[phone usps].include? address_delivery_method
    end
  end
end
