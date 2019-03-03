module Idv
  class RequestTokenForm
    include ActiveModel::Model
    include RequestTokenValidator

    ATTRIBUTES = [:token].freeze

    attr_accessor :token

    def self.model_name
      ActiveModel::Name.new(self, nil, 'RequestToken')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages,
                       extra: { user_id: capture_doc_request&.user_id })
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_token_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_token_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid token attribute"
    end
  end
end
