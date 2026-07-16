# frozen_string_literal: true

module Pii
  class UspsStrictAddressForm
    include ActiveModel::Validations
    include Pii::UspsStrictAddressValidator

    attr_reader(*ADDRESS_ATTRS)

    def initialize(address:)
      ADDRESS_ATTRS.each do |attr|
        instance_variable_set("@#{attr}", address[attr])
      end
    end
  end
end
