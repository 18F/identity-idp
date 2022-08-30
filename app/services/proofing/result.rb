module Proofing
  class Result
    attr_reader :exception
    attr_accessor :context, :transaction_id, :reference, :review_status

    def initialize(
      errors: {},
      context: {},
      exception: nil,
      transaction_id: nil,
      reference: nil
    )
      @errors = errors
      @context = context
      @exception = exception
      @transaction_id = transaction_id
      @reference = reference
    end

    # rubocop:disable Style/OptionalArguments
    def add_error(key = :base, error)
      (@errors[key] ||= Set.new).add(error)
      self
    end
    # rubocop:enable Style/OptionalArguments

    def errors
      @errors.transform_values(&:to_a)
    end

    def errors?
      @errors.any?
    end

    def exception?
      !@exception.nil?
    end

    def failed?
      !exception? && errors?
    end

    def success?
      !exception? && !errors?
    end

    def timed_out?
      @exception.is_a?(Proofing::TimeoutError)
    end

    def to_h
      {
        errors: errors,
        exception: exception,
        success: success?,
      }
    end
  end
end
