module Idv
  class Agent
    class << self
      def proofer_attribute?(key)
        Idv::Proofer.attribute?(key)
      end
    end

    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof(*stages)
      results = init_results

      stages.each do |stage|
        proofer_result = submit_applicant(applicant: @applicant, stage: stage, results: results)
        track_exception_in_result(proofer_result)
        results = merge_results(results, proofer_result)
        results[:timed_out] = proofer_result.timed_out?
        break unless proofer_result.success?
      end
      results
    end

    private

    def init_results
      {
        errors: {},
        messages: [],
        context: {
          stages: [],
        },
        exception: nil,
        success: false,
        timed_out: false,
      }
    end

    def submit_applicant(applicant:, stage:, results:)
      vendor = Idv::Proofer.get_vendor(stage).new
      log_vendor(vendor, results, stage)
      vendor.proof(applicant)
    end

    def log_vendor(vendor, results, stage)
      v_class = vendor.class
      results[:context][:stages].push(stage => v_class.vendor_name || v_class.inspect)
    end

    def merge_results(results, proofer_result)
      results.merge(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end
    end

    def track_exception_in_result(proofer_result)
      exception = proofer_result.exception
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end
  end
end
