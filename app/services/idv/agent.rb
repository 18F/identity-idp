module Idv
  class Agent
    class << self
      def proofer_attribute?(key)
        Idv::Proofer::ATTRIBUTES.include?(key)
      end
    end

    def initialize(applicant)
      @applicant = applicant.symbolize_keys!
    end

    def proof(*stages)
      results = { errors: [], messages: [], exception: nil, success: false }

      stages.each do |stage|
        vendor = Idv::Proofer::VENDORS[stage].new
        proofer_result = vendor.proof(@applicant)
        results = merge_results(results, proofer_result)
        break unless proofer_result.success?
      end

      results
    end

    private

    def merge_results(results, proofer_result)
      results.merge(proofer_result.to_h) do |key, v1, v2|
        key == :messages ? v1 + v2 : v2
      end
    end
  end
end
