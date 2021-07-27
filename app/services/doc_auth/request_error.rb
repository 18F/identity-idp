module IdentityDocAuth
  class RequestError < StandardError
    attr_reader :error_code
    def initialize(message, error_code)
      @error_code = error_code
      super(message)
    end
  end
end
