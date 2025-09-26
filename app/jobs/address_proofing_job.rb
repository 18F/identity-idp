# frozen_string_literal: true

class AddressProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_address_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  # rubocop:disable Lint/UnusedMethodArgument
  def perform(issuer:, result_id:, encrypted_arguments:, trace_id:, user_id: nil)
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    user = User.find(user_id)
    proofer_result = timer.time('address') do
      address_proofer(user:).proof(applicant_pii)
    end

    service_provider = ServiceProvider.find_by(issuer: issuer)
    Db::SpCost::AddSpCost.call(
      service_provider, :lexis_nexis_address, transaction_id: proofer_result.transaction_id
    )

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(proofer_result.to_h)
  rescue => e
    byebug
  ensure
    logger.info(
      {
        name: 'ProofAddress',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      }.to_json,
    )
  end
  # rubocop:enable Lint/UnusedMethodArgument

  private

  def address_proofer(user:)
    @address_proofer ||= begin
      address_vendor = address_vendor_ab_test_bucket ||
        IdentityConfig.store.idv_address_default_vendor

      case address_vendor
      when :lexis_nexis
        Proofing::LexisNexis::PhoneFinder::Proofer.new(
          phone_finder_workflow: IdentityConfig.store.lexisnexis_phone_finder_workflow,
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          username: IdentityConfig.store.lexisnexis_username,
          password: IdentityConfig.store.lexisnexis_password,
          hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
          hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
        )
      when :socure
        Proofing::Socure::IdPlus::AddressProofer.new(
          Proofing::Socure::IdPlus::Config.new(
            user_uuid: user.uuid,
            user_email: user.last_sign_in_email_address.email,
            api_key: IdentityConfig.store.socure_idplus_api_key,
            base_url: IdentityConfig.store.socure_idplus_base_url,
            timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
          ),
        )
      when :mock
        Proofing::Mock::AddressMockClient.new
      end
    end
  end

  def address_vendor_ab_test_bucket
    AbTests::ADDRESS_PROOFING_VENDOR.bucket(
      request: nil,
      service_provider: nil,
      session: nil,
      user: nil,
      user_session: nil,
    )
  end
end
