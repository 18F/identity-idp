# Needs the "raw" response error codes, which needs to happen before translation
class ExpiredLicenseAllower
  # @param IdentityDocAuth::Response
  def initialize(response)
    @response = response
  end

  # When we allow expired drivers licenses, returns a successful response
  # @return [IdentityDocAuth::Response]
  def processed_response
    if document_expired?
      if IdentityConfig.store.proofing_allow_expired_license && allowable_expired_license?
        IdentityDocAuth::Response.new(
          success: true, # new response with explicit true overrides success
          errors: {},
          exception: response.exception,
          extra: response.extra.merge(
            document_expired: document_expired?,
            reproof_at: reproof_at,
          ),
          pii_from_doc: response.pii_from_doc,
        )
      else
        response.merge(
          IdentityDocAuth::Response.new(
            success: true, # merge uses "&&" to combine success, so this does not override
            extra: {
              document_expired: document_expired?,
              would_have_passed: allowable_expired_license?
            },
          )
        )
      end
    else
      response
    end
  end

  def document_expired?
    !!response.errors[:id]&.include?(IdentityDocAuth::Errors::DOCUMENT_EXPIRED_CHECK)
  end

  def only_error_was_document_expired?
    response.errors.keys == [:id] &&
      response.errors[:id] == [IdentityDocAuth::Errors::DOCUMENT_EXPIRED_CHECK]
  end

  def allowable_expired_license?
    only_error_was_document_expired? &&
      response.pii_from_doc[:state_id_expiration] &&
      (state_id_expiration = Date.parse(response.pii_from_doc[:state_id_expiration])) &&
      state_id_expiration >= IdentityConfig.store.proofing_expired_license_after
  end

  def reproof_at
    IdentityConfig.store.proofing_expired_license_reproof_at.to_s
  end

  private

  attr_reader :response
end
