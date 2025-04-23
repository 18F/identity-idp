# frozen_string_literal: true

module Idv
  module InPerson
    class PassportForm
      include ActiveModel::Model

      ATTRIBUTES = %i[passport_surname passport_first_name passport_dob passport_number passport_expiration].freeze

      attr_accessor(*ATTRIBUTES)

      def self.model_name
        ActiveModel::Name.new(self, nil, 'InPersonPassport')
      end

      def initialize
      end
    end
  end
end
