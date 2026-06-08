# frozen_string_literal: true

module Pii
  class AddressForm
    include ActiveModel::Validations
    include Pii::AddressValidator

    attr_reader(*ADDRESS_ATTRS)

    def initialize(address:)
      ADDRESS_ATTRS.each do |attr|
        instance_variable_set("@#{attr}", address[attr])
      end
    end
  end
end
