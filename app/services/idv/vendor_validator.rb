# abstract base class for proofing vendor validation
module Idv
  class VendorValidator
    attr_reader :idv_session, :vendor_params

    def initialize(idv_session:, vendor_params:)
      @idv_session = idv_session
      @vendor_params = vendor_params
    end

    def validate
      raise NotImplementedError "Must implement validate for #{self}"
    end

    private

    def idv_vendor
      @_idv_vendor ||= Idv::Vendor.new
    end

    def idv_agent
      @_agent ||= Idv::Agent.new(
        applicant: idv_session.applicant,
        vendor: (idv_session.vendor || idv_vendor.pick)
      )
    end
  end
end
