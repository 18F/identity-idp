module Idv
  class VendorResult
    attr_reader :success,
                :errors,
                :messages,
                :context,
                :normalized_applicant,
                :timed_out,
                :exception

    def self.new_from_json(json)
      parsed = JSON.parse(json, symbolize_names: true)

      applicant = parsed[:normalized_applicant]
      parsed[:normalized_applicant] = applicant if applicant

      new(**parsed)
    end

    def initialize(success: nil, errors: {}, messages: [], context: {},
                   normalized_applicant: nil, timed_out: nil, exception: nil)
      @success = success
      @errors = errors
      @messages = messages
      @context = context
      @normalized_applicant = normalized_applicant
      @timed_out = timed_out
      @exception = exception
    end

    def success?
      success == true
    end

    def timed_out?
      timed_out == true
    end

    def job_failed?
      errors.fetch(:job_failed, false)
    end
  end
end
