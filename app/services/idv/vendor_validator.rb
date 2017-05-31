# abstract base class for proofing vendor validation
module Idv
  class VendorValidator
    delegate :success?, :errors, to: :result
    attr_reader :idv_session, :vendor_params

    def initialize(idv_session:, vendor_params:)
      @idv_session = idv_session
      @vendor_params = vendor_params
    end

    def reasons
      result.vendor_resp.reasons
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

    def result
      @_result ||= try_submit
    end

    def try_agent_action
      yield
    rescue => err
      err_msg = err.to_s
      NewRelic::Agent.notice_error(err)
      agent_error_resolution(err_msg)
    end

    def agent_error_resolution(err_msg)
      Proofer::Resolution.new(
        success: false,
        errors: { agent: [err_msg] },
        vendor_resp: Proofer::Vendor::MockResponse.new(
          reasons: [err_msg]
        )
      )
    end
  end
end
