module Proofing
  class DdpResult
    attr_reader :exception
    attr_accessor :context,
                  :success,
                  :transaction_id,
                  :review_status,
                  :response_body,
                  :client

    def initialize(
        success: true,
        errors: {},
        context: {},
        exception: nil,
        transaction_id: nil,
        review_status: nil,
        response_body: nil,
        client: nil
      )
      @success = success
      @errors = errors
      @context = context
      @exception = exception
      @transaction_id = transaction_id
      @response_body = response_body
      @review_status = review_status
      @client = client
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
      @success
    end

    def timed_out?
      @exception.is_a?(Proofing::TimeoutError)
    end

    def to_h
      {
        client:,
        success: success?,
        errors:,
        exception:,
        timed_out: timed_out?,
        transaction_id:,
        review_status:,
        response_body: Proofing::LexisNexis::Ddp::ResponseRedacter.redact(response_body),
      }
    end
  end
end
