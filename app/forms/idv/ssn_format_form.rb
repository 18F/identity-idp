module Idv
  class SsnFormatForm
    include ActiveModel::Model
    include FormSsnFormatValidator

    ATTRIBUTES = [:ssn].freeze

    attr_accessor :ssn

    def self.model_name
      ActiveModel::Name.new(self, nil, 'doc_auth')
    end

    def initialize(user, flow_session = {})
      @user = user
      @ssn = flow_session.dig('pii_from_doc', :ssn)
      @updating_ssn = ssn.present?
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: { pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]] },
      )
    end

    def updating_ssn?
      @updating_ssn
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
