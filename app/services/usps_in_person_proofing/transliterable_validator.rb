module UspsInPersonProofing
  # Validator that can be attached to a form or other model
  # to verify that specific supported fields are transliterable
  #
  # == Example
  #
  #   validates_with UspsInPersonProofing::TransliterableValidator,
  #     fields: [:first_name, :last_name]
  #
  class TransliterableValidator < ActiveModel::Validator
    # Initialize the validator with the given fields configured
    # for transliteration validation
    #
    # @param [Hash] options
    # @option options [Array<Symbol>] fields Fields for which to validate transliterability
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

    # Check if the configured values on the record are transliterable
    #
    # @param [ActiveModel::Validations] record
    def validate(record)
      return unless IdentityConfig.store.usps_ipp_transliteration_enabled
      helper.validate(
        @fields.index_with do |field|
          (record.send(field) if record.respond_to?(field))
        end,
      )&.each do |key, value|
        record.errors.add(key, :nontransliterable_field, message: value) unless value.nil?
      end
    end

    private

    # Fields supported by this validator
    SUPPORTED_FIELDS = UspsInPersonProofing::TransliterableValidatorHelper::SUPPORTED_FIELDS

    def helper
      @helper ||= UspsInPersonProofing::TransliterableValidatorHelper.new
    end
  end
end
