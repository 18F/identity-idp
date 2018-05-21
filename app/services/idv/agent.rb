module Idv
  class Agent
    class << self
      def proofer_attribute?(key)
        Idv::Proofer.attribute?(key)
      end
    end

    def initialize(applicant)
      @applicant = applicant.symbolize_keys!
    end

    def proof(*stages)
      results = init_results

      stages.each do |stage|
        vendor = Idv::Proofer.get_vendor(stage).new
        log_vendor(vendor, results, stage)
        proofer_result = vendor.proof(@applicant)
        results = merge_results(results, proofer_result)
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
      }
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
  end
end
