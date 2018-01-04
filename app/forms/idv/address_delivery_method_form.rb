module Idv
  class AddressDeliveryMethodForm
    attr_accessor :address_delivery_method

    def submit(params)
      self.address_delivery_method = params[:address_delivery_method]

      FormResponse.new(success: valid_address_delivery_method?, errors: {},
                       extra: extra_analytics_attributes)
    end

    private

    def extra_analytics_attributes
      {
        address_delivery_method: address_delivery_method,
      }
    end

    def valid_address_delivery_method?
      %w[phone usps].include? address_delivery_method
    end
  end
end
