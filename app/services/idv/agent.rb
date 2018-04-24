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
      results = {
        errors: {},
        normalized_applicant: {},
        reasons: [],
        success: false,
      }

      stages.each do |stage|
        proofer_result = proof_one(stage)
        vr = proofer_result.vendor_resp

        normalized_applicant = vr.respond_to?(:normalized_applicant) ? vr.normalized_applicant : nil

        results = {
          errors: results[:errors].merge(proofer_result.errors),
          normalized_applicant: normalized_applicant || results[:normalized_applicant],
          reasons: results[:reasons] + vr.reasons,
          success: proofer_result.success?,
        }

        break unless proofer_result.success?
      end

      results
    end

    def proof_one(stage)
      case stage

      when :phone
        get_agent(:phone_proofing_vendor).
          submit_phone(@applicant.phone)

      when :profile
        get_agent(:profile_proofing_vendor).
          start(@applicant.to_hash.with_indifferent_access)

      when :state_id
        get_agent(:state_id_proofing_vendor).
          submit_state_id(@applicant.to_hash.with_indifferent_access.merge(state_id_jurisdiction: @applicant.state))
      end
    end

    private

    def get_agent(vendor)
      Proofer::Agent.new(applicant: @applicant, vendor: Figaro.env.send(vendor).to_sym, kbv: false)
    end
  end
end
