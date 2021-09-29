module Idv
  class AddressForm
    include ActiveModel::Model
    include FormAddressValidator

    ATTRIBUTES = %i[state zipcode city address1 address2].freeze

    attr_accessor :state, :zipcode, :city, :address1, :address2

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Address')
    end

    def initialize(user)
      @user = user
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: { pii_like_keypaths: [[:errors, :zipcode ], [:error_details, :zipcode]] },
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
