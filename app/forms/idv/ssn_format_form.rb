module Idv
  class SsnFormatForm
    include ActiveModel::Model
    include FormSsnFormatValidator

    ATTRIBUTES = [:ssn].freeze

    attr_accessor :ssn

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Ssn')
    end

    def initialize(user)
      @user = user
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: { pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]] },
      )
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_ssn_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_ssn_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid ssn attribute"
    end
  end
end
