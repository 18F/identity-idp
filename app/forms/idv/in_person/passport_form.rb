# frozen_string_literal: true

module Idv
  module InPerson
    class PassportForm
      include ActiveModel::Model

      ATTRIBUTES = %i[surname first_name dob passport_number passport_expiration].freeze

      attr_accessor(*ATTRIBUTES)

      def self.model_name
        ActiveModel::Name.new(self, nil, 'InPersonPassport')
      end

      # def initialize(pii)
      #   @pii = pii
      # end
    end
  end
end