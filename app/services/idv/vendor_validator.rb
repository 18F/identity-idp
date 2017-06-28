# abstract base class for proofing vendor validation
module Idv
  class VendorValidator
    attr_reader :applicant, :vendor, :vendor_params, :vendor_session_id

    def initialize(applicant:, vendor:, vendor_params:, vendor_session_id:)
      @applicant = applicant
      @vendor = vendor
      @vendor_params = vendor_params
      @vendor_session_id = vendor_session_id
    end

    def result
      @_result ||= try_submit
    end

    private

    def idv_agent
      @_agent ||= Idv::Agent.new(
        applicant: applicant,
        vendor: vendor
      )
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
        vendor_resp: OpenStruct.new(reasons: [err_msg])
      )
    end
  end
end
