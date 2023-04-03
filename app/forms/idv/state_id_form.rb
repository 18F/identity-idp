module Idv
  class StateIdForm
    include ActiveModel::Model
    include FormStateIdValidator

    ATTRIBUTES = %i[first_name last_name dob state_id_address1 state_id_address2
                    state_id_city state_id_zipcode state_id_jurisdiction
                    state_id_state state_id_number same_address_as_id].freeze

    attr_accessor(*ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'StateId')
    end

    def initialize(pii)
      @pii = pii
    end

    def submit(params)
      consume_params(params)

      cleaned_errors = errors.deep_dup
      cleaned_errors.delete(:first_name, :nontransliterable_field)
      cleaned_errors.delete(:last_name, :nontransliterable_field)

      FormResponse.new(
        success: valid?,
        errors: cleaned_errors,
      )
    end

    private

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
