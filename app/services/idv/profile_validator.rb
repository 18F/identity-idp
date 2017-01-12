module Idv
  class ProfileValidator < VendorValidator
    def validate
      idv_session.applicant = vendor_params
      idv_session.vendor = idv_agent.vendor
      idv_session.resolution = idv_agent.start(vendor_params)
      idv_session.resolution.success?
    end
  end
end
