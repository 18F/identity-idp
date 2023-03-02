module Idv
  class StateIdForm
    include ActiveModel::Model
    include FormStateIdValidator

    ATTRIBUTES = %i[first_name last_name dob state_id_jurisdiction state_id_number].freeze

    attr_accessor(*ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'StateId')
    end

    def initialize(pii)
      @pii = pii
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
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
