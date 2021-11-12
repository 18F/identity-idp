module Telephony
  class Response
    attr_reader :error, :extra

    def initialize(success:, error: nil, extra: {})
      @success = success
      @error = error
      @extra = extra
    end

    def errors
      return {} if error.nil?
      {
        telephony: "#{error.class} - #{error.message}",
      }
    end

    def success?
      @success == true
    end

    def to_h
      { success: success, errors: errors }.merge!(extra)
    end

    private

    attr_reader :success
  end
end
