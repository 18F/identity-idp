# frozen_string_literal: true

module Idv
  class AddressForm
    include ActiveModel::Model
    include FormAddressValidator

    ATTRIBUTES = %i[state zipcode city address1 address2].freeze

    attr_accessor(*ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'IdvForm')
    end

    def initialize(pii)
      set_ivars_with_pii(pii)
      @address_edited = false
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          address_edited: @address_edited,
          pii_like_keypaths: [[:errors, :zipcode], [:error_details, :zipcode]],
        },
      )
    end

    private

    def set_ivars_with_pii(pii)
      pii = pii.symbolize_keys
      @address1 = pii[:address1]
      @address2 = pii[:address2]
      @city = pii[:city]
      @state = pii[:state]
      @zipcode = pii[:zipcode]
    end

    def consume_params(params)
      ATTRIBUTES.each do |attribute_name|
        if send(attribute_name).to_s != params[attribute_name].to_s
          @address_edited = true
        end
        send(:"#{attribute_name}=", params[attribute_name].to_s)
      end
    end

    def raise_invalid_address_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid address attribute"
    end
  end
end
