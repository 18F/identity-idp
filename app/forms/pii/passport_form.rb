# frozen_string_literal: true

module Pii
  class PassportForm
    include ActiveModel::Validations
    include Pii::PassportValidator

    attr_reader(*PASSPORT_ATTRS)

    def initialize(passport:)
      PASSPORT_ATTRS.each do |attr|
        instance_variable_set("@#{attr}", passport[attr])
      end
    end
  end
end
