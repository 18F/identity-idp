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

    def proof(vendor_params, *stages)

      initial_value = {
        errors: {}
        normalized_applicant: {}
        reasons: []
        success: false
      }

      stages.reduce(initial_value) do |results, stage|
        proofer_result = proof_one(vendor_params, stage)

        results[:errors] = results[:errors].merge(proofer_result.errors)
        results[:normalized_applicant] = proofer_result.normalized_applicant if proofer_result.normalized_applicant
        results[:reasons] = results[:reasons] + proofer_result.vendor_resp.reasons)
        results[:success] = proofer_result.success?

        break unless proofer_result.success?
      end
    end

    def proof_one(vendor_params, stage)
      v_params = vendor_params.with_indifferent_access
      case stage

        when :phone
          Proofer::Agent.
            new(applicant: @applicant, vendor: Figaro.env.phone_proofing_vendor.to_sym, kbv: false).
            submit_phone(v_params)

        when :profile
          Proofer::Agent.
            new(applicant: @applicant, vendor: Figaro.env.profile_proofing_vendor.to_sym, kbv: false).
            start(v_params)

        when :state_id
          Proofer::Agent.
            new(applicant: @applicant, vendor: Figaro.env.state_id_proofing_vendor.to_sym, kbv: false).
            submit_state_id(v_params.merge(state_id_jurisdiction: v_params[:state]))
      end
    end
  end
end
