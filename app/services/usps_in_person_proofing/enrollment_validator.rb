module UspsInPersonProofing
  class EnrollmentValidator
    SUPPORTED_FIELDS = [
      :first_name,
      :last_name,
      :address1,
      :address2,
      :city,
    ].freeze

    def initialize(transliterator = Transliterator.new)
      @transliterator = transliterator
    end

    # Validate that transliteratable fields from the state ID form
    # can be transliterated to contain acceptable characters.
    #
    # @param [Hash] fields Name/value pairs of fields to validate
    # @option fields [String,#to_s] :first_name
    # @option fields [String,#to_s] :last_name
    # @option fields [String,#to_s] :address1
    # @option fields [String,#to_s] :address2
    # @option fields [String,#to_s] :city
    # @return [Hash,nil] Field names mapped to error messages, or nil if there were no issues
    def validate(fields)
      validation_result = {}
      fields.slice(*SUPPORTED_FIELDS).each do |key, value|
        # Get transliterated value
        result = @transliterator.transliterate(value)
        transliterated = result.transliterated

        # Remove question marks corresponding with unsupported chars
        # for transliteration
        result.unsupported_chars.each do |chr|
          transliterated = transliterated.sub(Transliterator::REPLACEMENT, '')
        end

        # Scan for unsupported chars for the field
        additional_chars = transliterated.scan(ADDITIONAL_UNSUPPORTED_CHARS[key])

        # Create sorted list of unique unsupported characters
        unsupported_char_list = (result.unsupported_chars + additional_chars).sort.uniq

        # Use unsupported character list to generate error message
        unless unsupported_char_list.empty?
          validation_result[key] = send(
            UNSUPPORTED_CHARS_TRANSLATION[key],
            unsupported_char_list,
          )
        end
      end

      validation_result if validation_result.compact.size > 0
    end

    private

    ADDITIONAL_UNSUPPORTED_CHARS = ActiveSupport::HashWithIndifferentAccess.new(
      first_name: /[^A-Za-z\-' ]/,
      last_name: /[^A-Za-z\-' ]/,
      address1: /[^A-Za-z0-9\-' .\/#]/,
      address2: /[^A-Za-z0-9\-' .\/#]/,
      city: /[^A-Za-z\-' ]/,
    ).freeze

    UNSUPPORTED_CHARS_TRANSLATION = ActiveSupport::HashWithIndifferentAccess.new(
      first_name: :translate_name_chars_error,
      last_name: :translate_name_chars_error,
      address1: :translate_address_chars_error,
      address2: :translate_address_chars_error,
      city: :translate_address_chars_error,
    ).freeze

    def translate_name_chars_error(chars)
      I18n.t(
        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
        char_list: chars.join(', '),
      )
    end

    def translate_address_chars_error(chars)
      I18n.t(
        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
        char_list: chars.join(', '),
      )
    end
  end
end
