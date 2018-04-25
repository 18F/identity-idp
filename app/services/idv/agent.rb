module Idv
  class Agent
    class << self
      def proofer_attribute?(key)
        Proofer::Applicant.method_defined?(key)
      end
    end

    def initialize(applicant)
      @applicant = Proofer::Applicant.new(applicant)
    end

    def proof(*stages)
      results = { errors: {}, normalized_applicant: {}, reasons: [], success: false }

      stages.each do |stage|
        proofer_result = proof_one(stage)
        results = merge_results(results, proofer_result)
        break unless proofer_result.success?
      end

      results
    end

    def proof_one(stage)
      applicant_hash = @applicant.to_hash.with_indifferent_access

      case stage

      when :phone
        get_agent(:phone_proofing_vendor).submit_phone(@applicant.phone)

      when :profile
        get_agent(:profile_proofing_vendor).start(applicant_hash)

      when :state_id
        get_agent(:state_id_proofing_vendor).
          submit_state_id(applicant_hash.merge(state_id_jurisdiction: @applicant.state))
      end
    end

    private

    def merge_results(results, proofer_result)
      vr = proofer_result.vendor_resp

      normalized_applicant = vr.try(:normalized_applicant) || {}

      {
        errors: results[:errors].merge(proofer_result.errors),
        normalized_applicant: results[:normalized_applicant].merge(normalized_applicant),
        reasons: results[:reasons] + vr.reasons,
        success: proofer_result.success?,
      }
    end

    def get_agent(vendor)
      Proofer::Agent.new(applicant: @applicant, vendor: Figaro.env.send(vendor).to_sym, kbv: false)
    end
  end
end
