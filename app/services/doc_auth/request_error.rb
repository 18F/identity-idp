# frozen_string_literal: true

module DocAuth
  class RequestError < StandardError
    attr_reader :error_code
    def initialize(message, error_code)
      @error_code = error_code
      super(message)
    end
  end
end
