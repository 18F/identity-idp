module Acuant
  class Response
    attr_reader :errors, :exception, :extra

    def initialize(success:, errors: [], exception: nil, extra: {})
      @success = success
      @errors = errors
      @exception = exception
      @extra = extra
    end

    def success?
      @success
    end

    def to_h
      {
        success: success?,
        errors: errors,
        exception: exception,
      }.merge(extra)
    end
  end
end
