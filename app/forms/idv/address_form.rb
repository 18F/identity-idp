module Idv
  class AddressForm
    include ActiveModel::Model
    include FormAddressValidator

    ATTRIBUTES = %i[state zipcode city address1 address2].freeze

    attr_accessor(*ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Address')
    end

    def initialize(pii)
      @pii = pii
      @address_edited = false
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          address_edited: @address_edited,
          pii_like_keypaths: [[:errors, :zipcode ], [:error_details, :zipcode]],
        },
      )
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_address_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
        if send(key) != @pii[key] && (send(key).present? || @pii[key].present?)
          @address_edited = true
        end
      end
    end

    def raise_invalid_address_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid address attribute"
    end
  end
end
