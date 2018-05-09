module Idv
  class StateForm
    include ActiveModel::Model
    include FormStateValidator

    ATTRIBUTES = [:state].freeze

    attr_accessor :state

    def self.model_name
      ActiveModel::Name.new(self, nil, 'State')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_state_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_state_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid state attribute"
    end
  end
end
