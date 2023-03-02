module UspsInPersonProofing
  class TransliterableValidator < ActiveModel::Validator
    def initialize(options)
      super
      @fields = options[:fields]
      if (@fields & SUPPORTED_FIELDS).size < @fields.size
        # Catch incorrect usage of the validator
        raise StandardError.new(
          "Unsupported transliteration fields: #{(@fields - SUPPORTED_FIELDS).to_json}",
        )
      end
    end

    def validate(record)
      validator.validate(
        @fields.index_with do |field|
          (record.send(field) if record.respond_to?(field))
        end,
      )&.each do |key, value|
        record.errors.add(key, value, type: :nontransliterable_field) unless value.nil?
      end
    end

    private

    SUPPORTED_FIELDS = UspsInPersonProofing::EnrollmentValidator::SUPPORTED_FIELDS

    def validator
      @validator ||= UspsInPersonProofing::EnrollmentValidator.new
    end
  end
end
