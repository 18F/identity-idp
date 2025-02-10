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

    def initialize(initial_address)
      consume_attributes_from_address(initial_address.to_h)
    end

    def submit(params)
      consume_attributes_from_address(params.to_h)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          pii_like_keypaths: [[:errors, :zipcode], [:error_details, :zipcode]],
        },
      )
    end

    def updated_user_address
      return nil unless valid?

      Pii::Address.new(
        address1: address1,
        address2: address2,
        city: city,
        state: state,
        zipcode: zipcode,
      )
    end

    private

    def consume_attributes_from_address(address_hash)
      address_hash = address_hash.symbolize_keys
      @address1 = address_hash[:address1].to_s.strip
      @address2 = address_hash[:address2].to_s.strip
      @city = address_hash[:city].to_s.strip
      @state = address_hash[:state].to_s.strip
      @zipcode = address_hash[:zipcode].to_s.strip
    end
  end
end
