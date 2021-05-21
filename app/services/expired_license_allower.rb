# Needs the "raw" response error codes, which needs to happen before translation
class ExpiredLicenseAllower
  # @param IdentityDocAuth::Response
  def initialize(response)
    @response = response
  end

  # When we allow expired drivers licenses, returns a successful response
  # @return [IdentityDocAuth::Response]
  def processed_response
    if allow_expired_license?
      IdentityDocAuth::Response.new(
        success: true,
        errors: response.errors,
        exception: response.exception,
        extra: response.extra.merge(
          expired_document: true,
          reproof_at: IdentityConfig.store.proofing_expired_license_reproof_at.to_s,
        ),
        pii_from_doc: response.pii_from_doc,
      )
    else
      response
    end
  end

  def only_error_expired?
    response.errors.keys == [:id] &&
      response.errors[:id] == [IdentityDocAuth::Errors::DOCUMENT_EXPIRED_CHECK]
  end

  def allow_expired_license?
    IdentityConfig.store.proofing_allow_expired_license &&
      only_error_expired? &&
      response.pii_from_doc[:state_id_expiration] &&
      (state_id_expiration = Date.parse(response.pii_from_doc[:state_id_expiration])) &&
      state_id_expiration >= IdentityConfig.store.proofing_expired_license_after
  end

  private

  attr_reader :response
end
