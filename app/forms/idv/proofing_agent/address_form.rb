# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AddressForm
      include ActiveModel::Validations
      include AddressValidator

      attr_reader(*ADDRESS_ATTRS)

      def initialize(address:)
        ADDRESS_ATTRS.each do |attr|
          instance_variable_set("@#{attr}", address[attr])
        end
      end
    end
  end
end
