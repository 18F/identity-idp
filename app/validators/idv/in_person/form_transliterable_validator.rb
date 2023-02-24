module Idv
  module InPerson
    module FormTransliterableValidator
      extend ActiveSupport::Concern

      included do
        def self.transliterate(*fields)
          supported_fields = UspsInPersonProofing::EnrollmentValidator::SUPPORTED_FIELDS
          if (fields & supported_fields).size < fields.size
            # Catch incorrect usage of the validator
            raise StandardError.new("Unsupported transliteration fields: #{(fields - supported_fields).to_json}")
          end
          @@transliterable_fields ||= []
          validate :transliterable_check if @@transliterable_fields.empty? && !fields.empty?
          @@transliterable_fields.push(*fields)
        end

        private

        def transliterable_check
            FormTransliterableValidator.validator.validate(
                @@transliterable_fields.map do |field|
                    method = field.to_sym
                    if respond_to?(method)
                        [field, send(method)]
                    else
                        [field, nil]
                    end
                end.to_h
            )&.each do |key, value|
                unless value.nil?
                    errors.add(key, value)
                end
            end
        end
      end

      private

      def self.validator
          @validator ||= UspsInPersonProofing::EnrollmentValidator.new
      end
    end
  end
end
