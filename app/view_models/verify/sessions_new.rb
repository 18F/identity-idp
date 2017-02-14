module Verify
  class SessionsNew < Verify::Base
    def mock_vendor_partial
      if idv_vendor.pick == :mock
        'verify/sessions/no_pii_warning'
      else
        'shared/null'
      end
    end

    def step_name
      :sessions
    end

    private

    def idv_vendor
      @_idv_vendor ||= Idv::Vendor.new
    end
  end
end
