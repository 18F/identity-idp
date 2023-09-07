module Idv
  class StateIdForm
    include ActiveModel::Model
    include FormStateIdValidator

    ATTRIBUTES = %i[first_name last_name dob identity_doc_address1 identity_doc_address2
                    identity_doc_city identity_doc_zipcode state_id_jurisdiction
                    identity_doc_address_state state_id_number same_address_as_id].freeze

    attr_accessor(*ATTRIBUTES)

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
      )
    end

    private

    attr_reader :capture_secondary_id_enabled
      alias_method :capture_secondary_id_enabled?, :capture_secondary_id_enabled

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_state_id_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_state_id_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid state ID attribute"
    end
  end
end
