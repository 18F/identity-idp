module Idv
  class ProfileValidator < VendorValidator
    delegate :session_id, to: :result

    def result
      @_result ||= try_start
    end

    def normalized_applicant
      result.vendor_resp.normalized_applicant
    end

    private

    def try_start
      try_agent_action do
        idv_agent.start(vendor_params)
      end
    end
  end
end
