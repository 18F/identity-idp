module Idv
  module InPerson
    module FormTransliterableValidator
      extend ActiveSupport::Concern
      def self.included(base)
        class << base
          def transliterate(*fields)
            if (fields & SUPPORTED_FIELDS).size < fields.size
              # Catch incorrect usage of the validator
              raise StandardError.new(
                "Unsupported transliteration fields: #{(fields - SUPPORTED_FIELDS).to_json}",
              )
            end

            @transliterable_fields ||= []
            if @transliterable_fields.empty? && !fields.empty?
              check = self.method(:transliterable_check)
              validate do
                check.call(self)
              end
            end
            @transliterable_fields.push(*fields)
          end

          private

          SUPPORTED_FIELDS = UspsInPersonProofing::EnrollmentValidator::SUPPORTED_FIELDS

          def transliterable_check(form)
            validator.validate(
              @transliterable_fields.index_with do |field|
                (form.send(field) if form.respond_to?(field))
              end,
            )&.each do |key, value|
              form.errors.add(key, value, type: :nontransliterable_field) unless value.nil?
            end
          end

          def validator
            @validator ||= UspsInPersonProofing::EnrollmentValidator.new
          end
        end
      end
    end
  end
end
