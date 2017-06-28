module Idv
  class ProfileValidator < VendorValidator
    def result
      @_result ||= try_start
    end

    private

    def try_start
      try_agent_action do
        idv_agent.start(vendor_params)
      end
    end
  end
end
