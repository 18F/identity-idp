# frozen_string_literal: true

module UspsInPersonProofing
  # Validator that can be attached to a form or other model
  # to verify that specific supported fields are transliterable
  # and conform to additional character requirements
  #
  # == Example
  #
  #   validates_with UspsInPersonProofing::TransliterableValidator,
  #     fields: [:first_name, :last_name],
  #     reject_chars: /[^A-Za-z\-' ]/,
  #     message: ->(invalid_chars)
  #       "Rejected chars: #{invalid_chars.join(', ')}"
  #     end
  #
  class TransliterableValidator < ActiveModel::Validator
    # Initialize the validator with the given fields configured
    # for transliteration validation
    #
    # @param [Hash] options
    # @option options [Array<Symbol>] fields Fields for which to validate transliterability
    # @option options [Regexp] reject_chars Regex of chars to reject post-transliteration
    # @option options [String,#call] message Error message or message generator
    def initialize(options)
      super
      @fields = options[:fields]
      @reject_chars = options[:reject_chars]
      @message = options[:message]
    end

    # Check if the configured values on the record are transliterable
    #
    # @param [ActiveModel::Validations] record
    def validate(record)
      return unless IdentityConfig.store.usps_ipp_transliteration_enabled
      nontransliterable_chars = Set.new
      @fields.each do |field|
        next unless record.respond_to?(field)

        value = record.send(field)
        next unless value.respond_to?(:to_s)

        invalid_chars = get_invalid_chars(value)
        next unless invalid_chars.present?

        nontransliterable_chars += invalid_chars

        record.errors.add(
          field,
          :nontransliterable_field,
          message: get_error_message(invalid_chars),
        )
      end

      if nontransliterable_chars.present?
        analytics.idv_in_person_proofing_nontransliterable_characters_submitted(
          nontransliterable_characters: nontransliterable_chars.sort,
        )
      end
    end

    def transliterator
      @transliterator ||= Transliterator.new
    end

    private

    # Use unsupported character list to generate error message
    def get_error_message(unsupported_chars)
      return unless unsupported_chars.present?
      if @message.respond_to?(:call)
        @message.call(unsupported_chars)
      else
        @message
      end
    end

    def get_invalid_chars(value)
      # Get transliterated value
      result = transliterator.transliterate(value)
      transliterated = result.transliterated

      # Remove question marks corresponding with unsupported chars
      # for transliteration
      unless transliterated.count(Transliterator::REPLACEMENT) > result.unsupported_chars.length
        transliterated = transliterated.gsub(Transliterator::REPLACEMENT, '')
      end

      # Scan for unsupported chars for the field
      if @reject_chars.is_a?(Regexp)
        additional_chars = transliterated.scan(@reject_chars)
      else
        additional_chars = []
      end

      # Create sorted list of unique unsupported characters
      (result.unsupported_chars + additional_chars).sort.uniq
    end

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end
  end
end
