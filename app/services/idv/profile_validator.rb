module Idv
  class ProfileValidator < VendorValidator
    def result
      @_result ||= idv_agent.start(vendor_params)
    end
  end
end
