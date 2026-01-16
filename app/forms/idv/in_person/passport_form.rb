# frozen_string_literal: true

module Idv
  module InPerson
    class PassportForm
      include ActiveModel::Model
      include Idv::InPerson::FormPassportValidator

      ATTRIBUTES = %i[passport_surname passport_first_name passport_dob passport_number
                      passport_expiration].freeze

      attr_accessor(*ATTRIBUTES)

      def self.model_name
        ActiveModel::Name.new(self, nil, 'InPersonPassport')
      end

      def submit(params)
        set_form_attributes(params)
        success = valid?
        FormResponse.new(success:, errors:)
      end

      private

      def set_form_attributes(params)
        params.each do |key, value|
          send(:"#{key}=", value)
        end
      end
    end
  end
end
