module Idv
  class VendorResult
    attr_reader :success, :errors, :reasons, :normalized_applicant, :timed_out

    def self.new_from_json(json)
      parsed = JSON.parse(json, symbolize_names: true)

      applicant = parsed[:normalized_applicant]
      parsed[:normalized_applicant] = Proofer::Applicant.new(applicant) if applicant

      new(**parsed)
    end

    def initialize(success: nil, errors: {}, reasons: [],
                   normalized_applicant: nil, timed_out: nil)
      @success = success
      @errors = errors
      @reasons = reasons
      @normalized_applicant = normalized_applicant
      @timed_out = timed_out
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
