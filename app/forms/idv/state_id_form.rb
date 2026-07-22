# frozen_string_literal: true

module Idv
  class StateIdForm
    include ActiveModel::Model

    # Radio option indicating the user is entering a calendar expiration date.
    EXPIRATION_OPTION_DATE = 'date'
    # Sentinel values stored in state_id_expiration when the ID has no standard
    # expiration date. These are also the radio option values for those choices.
    EXPIRATION_MILITARY = 'military'
    EXPIRATION_INDEFINITE = 'indefinite'
    EXPIRATION_NONE = 'none'
    EXPIRATION_SENTINELS = [EXPIRATION_MILITARY, EXPIRATION_INDEFINITE, EXPIRATION_NONE].freeze
    EXPIRATION_OPTIONS = [EXPIRATION_OPTION_DATE, *EXPIRATION_SENTINELS].freeze
    # Literal placeholder dates that appear on some IDs and are stored verbatim.
    PLACEHOLDER_EXPIRATION_DATES = %w[9999-99-99 0000-00-00].freeze
    # Any value we should not transmit to USPS as a real expiration date.
    NON_STANDARD_EXPIRATIONS = (EXPIRATION_SENTINELS + PLACEHOLDER_EXPIRATION_DATES).freeze

    ATTRIBUTES = %i[first_name last_name dob identity_doc_address1 identity_doc_address2
                    identity_doc_city identity_doc_zipcode state_id_jurisdiction
                    identity_doc_address_state state_id_number same_address_as_id
                    id_expiration id_expiration_option].freeze

    attr_accessor(*ATTRIBUTES)

    include FormStateIdValidator

    def self.model_name
      ActiveModel::Name.new(self, nil, 'StateId')
    end

    def initialize(pii)
      @pii = pii
    end

    def submit(params)
      consume_params(params)
      validation_success = valid?
      cleaned_errors = errors.dup
      cleaned_errors.delete(:first_name, :nontransliterable_field)
      cleaned_errors.delete(:last_name, :nontransliterable_field)
      cleaned_errors.delete(:identity_doc_city, :nontransliterable_field)
      cleaned_errors.delete(:identity_doc_address1, :nontransliterable_field)
      cleaned_errors.delete(:identity_doc_address2, :nontransliterable_field)

      FormResponse.new(
        success: validation_success,
        errors: cleaned_errors,
        extra: extra_analytics_attributes(params),
      )
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_state_id_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send(:"#{key}=", value)
      end
    end

    def raise_invalid_state_id_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid state ID attribute"
    end

    def extra_analytics_attributes(params)
      { birth_year: params.dig(:dob, :year),
        document_zip_code: params.dig(:identity_doc_zipcode)&.slice(0, 5) }
    end
  end
end
