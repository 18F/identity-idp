class SubmitIdvJob
  def initialize(vendor_validator_class:, idv_session:, vendor_params:)
    @vendor_validator_class = vendor_validator_class
    @idv_session = idv_session
    @vendor_params = vendor_params
  end

  def call
    update_idv_session

    VendorValidatorJob.perform_later(
      result_id: result_id,
      vendor_validator_class: vendor_validator_class.to_s,
      vendor: vendor.to_s,
      vendor_params: vendor_params,
      vendor_session_id: idv_session.vendor_session_id,
      applicant_json: idv_session.applicant.to_json
    )
  end

  private

  attr_reader :vendor_validator_class, :idv_session, :vendor_params

  def result_id
    @_result_id ||= SecureRandom.uuid
  end

  def update_idv_session
    idv_session.async_result_id = result_id
    idv_session.async_result_started_at = Time.zone.now.to_i
  end

  def vendor
    idv_session.vendor || Idv::Vendor.new.pick
  end
end
