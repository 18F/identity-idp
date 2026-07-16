# frozen_string_literal: true

module Idv
  module ProofingAgent
    class PassportForm
      include ActiveModel::Validations
      include PassportValidator

      attr_reader(*PASSPORT_ATTRS)

      def initialize(passport:)
        PASSPORT_ATTRS.each do |attr|
          instance_variable_set("@#{attr}", passport[attr])
        end
      end
    end
  end
end
