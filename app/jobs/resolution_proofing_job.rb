# frozen_string_literal: true

class ResolutionProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_resolution_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :residential_resolution_success,
    :state_id_success,
    :device_profiling_success,
    keyword_init: true,
  )

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    ipp_enrollment_in_progress:,
    proofing_vendor:,
    user_id: nil,
    service_provider_issuer: nil,
    threatmetrix_session_id: nil,
    request_ip: nil,
    proofing_components: nil,
    trusted_referee_request_id: nil,
    trusted_referee_webhook_endpoint: nil
  )
    timer = JobHelpers::Timer.new

    user = User.find_by(id: user_id)

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    current_sp = ServiceProvider.find_by(issuer: service_provider_issuer)

    applicant_pii = decrypted_args[:applicant_pii]
    applicant_pii[:uuid_prefix] = current_sp&.app_id
    applicant_pii[:uuid] = user.uuid

    callback_log_data = make_vendor_proofing_requests(
      timer:,
      user:,
      applicant_pii:,
      threatmetrix_session_id:,
      request_ip:,
      ipp_enrollment_in_progress:,
      current_sp:,
      proofing_vendor:,
    )

    ssn_is_unique = Idv::DuplicateSsnFinder.new(
      ssn: applicant_pii[:ssn],
      user: user,
    ).ssn_is_unique?

    callback_log_data.result[:ssn_is_unique] = ssn_is_unique

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    result = callback_log_data.result
    document_capture_session.store_proofing_result(result)
  rescue => e
    byebug
  ensure
    send_trusted_referee_webhook(endpoint: trusted_referee_webhook_endpoint, result:, user_uuid: user.uuid, request_id: trusted_referee_request_id)
    logger_info_hash(
      name: 'ProofResolution',
      proofing_vendor:,
      trace_id: trace_id,
      resolution_success: callback_log_data&.resolution_success,
      residential_resolution_success: callback_log_data&.residential_resolution_success,
      state_id_success: callback_log_data&.state_id_success,
      device_profiling_success: callback_log_data&.device_profiling_success,
      timing: timer.results,
      user_id: user.uuid,
    )

    if use_shadow_mode?(user:, proofing_components:)
      SocureShadowModeProofingJob.perform_later(
        document_capture_session_result_id: document_capture_session&.result_id,
        encrypted_arguments:,
        service_provider_issuer:,
        user_email: user_email_for_proofing(user),
        user_uuid: user.uuid,
      )
    end
  end

  # @param user [User]
  # @param proofing_components [Hash,nil]
  def use_shadow_mode?(user:, proofing_components:)
    # Let idv_socure_shadow_mode_enabled setting control shadow mode globally
    disabled_globally = !IdentityConfig.store.idv_socure_shadow_mode_enabled
    return false if disabled_globally

    # If the user went through Socure docv, they are already a Socure user and
    # are thus eligible for shadow mode.
    enabled_for_docv_users =
      IdentityConfig.store.idv_socure_shadow_mode_enabled_for_docv_users
    is_docv_user = proofing_components&.dig(:document_check) == Idp::Constants::Vendors::SOCURE
    return true if enabled_for_docv_users && is_docv_user

    # Otherwise fall back to A/B test
    shadow_mode_ab_test_bucket(user:) == :socure_shadow_mode_for_non_docv_users
  end

  private

  # @return [CallbackLogData]
  def make_vendor_proofing_requests(
    timer:,
    user:,
    applicant_pii:,
    threatmetrix_session_id:,
    request_ip:,
    ipp_enrollment_in_progress:,
    current_sp:,
    proofing_vendor:
  )
    user_email = user_email_for_proofing(user) || applicant_pii[:email]
    result = progressive_proofer(user:, proofing_vendor:, user_email:).proof(
      applicant_pii: applicant_pii,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      ipp_enrollment_in_progress: ipp_enrollment_in_progress,
      timer: timer,
      current_sp: current_sp,
      workflow: :idv,
    )

    log_threatmetrix_info(result.device_profiling_result, user)

    CallbackLogData.new(
      device_profiling_success: result.device_profiling_result.success?,
      resolution_success: result.resolution_result.success?,
      residential_resolution_success: result.residential_resolution_result.success?,
      result: result.adjudicated_result.to_h,
      state_id_success: result.state_id_result.success?,
    )
  end

  def user_email_for_proofing(user)
    user.last_sign_in_email_address&.email
  end

  def log_threatmetrix_info(threatmetrix_result, user)
    logger_info_hash(
      name: 'ThreatMetrix',
      user_id: user.uuid,
      threatmetrix_request_id: threatmetrix_result.transaction_id,
      threatmetrix_success: threatmetrix_result.success?,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end

  def progressive_proofer(user:, proofing_vendor:, user_email:)
    @progressive_proofer ||= Proofing::Resolution::ProgressiveProofer.new(
      user_uuid: user.uuid, proofing_vendor:, user_email:,
    )
  end

  def shadow_mode_ab_test_bucket(user:)
    AbTests::SOCURE_IDV_SHADOW_MODE_FOR_NON_DOCV_USERS.bucket(
      request: nil,
      service_provider: nil,
      session: nil,
      user:,
      user_session: nil,
    )
  end

  def send_trusted_referee_webhook(endpoint: nil, result:, request_id:, user_uuid:)
    if endpoint
      # send back failure with reasons
      body = {
        reason: 'because ...',
        request_id:,
        uid: user_uuid,
      }
      send_http_post_request(endpoint:, body:)
    end
  rescue => exception
    byebug
    NewRelic::Agent.notice_error(
      exception,
      custom_params: {
        event: 'Failed to send webhook',
        endpoint:,
        body:,
      },
    )
  ensure
    # log to analytics
  end

  def send_http_post_request(endpoint: IdentityConfig.store.trusted_referee_webhook_endpoint, body:)
    puts "body:\t#{body.inspect}"
    puts "endpoint:\t#{endpoint}"
    faraday_connection(endpoint).post do |req|
      req.options.context = { service_name: 'trusted_referee webhook' }
      req.body = body.to_json
    end
  end

  def faraday_connection(endpoint)
    retry_options = {
      max: 2,
      interval: 0.05,
      interval_randomness: 0.5,
      backoff_factor: 2,
      retry_statuses: [404, 500],
      retry_block: lambda do |env:, options:, retry_count:, exception:, will_retry_in:|
        NewRelic::Agent.notice_error(exception, custom_params: { retry: retry_count })
      end,
    }

    timeout = 15

    Faraday.new(url: url(endpoint).to_s, headers: request_headers) do |conn|
      conn.request :retry, retry_options
      conn.request :instrumentation, name: 'request_metric.faraday'
      conn.adapter :net_http
      conn.options.timeout = timeout
      conn.options.read_timeout = timeout
      conn.options.open_timeout = timeout
      conn.options.write_timeout = timeout
    end
  end

  def url(endpoint)
    URI.join(endpoint)
  end

  def request_headers(extras = {})
    {
      'Content-Type': 'application/json',
      # Authorization: "SocureApiKey #{IdentityConfig.store.socure_idplus_api_key}",
    }.merge(extras)
  end
end
