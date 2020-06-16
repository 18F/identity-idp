module Acuant
  class Response
    attr_reader :errors, :exception

    def initialize(success:, errors: [], exception: nil)
      @success = success
      @errors = errors
      @exception = exception
    end

    def success?
      @success
    end

    def to_h
      {
        success: success?,
        erorrs: errors,
        exception: exception,
      }
    end
  end
end
