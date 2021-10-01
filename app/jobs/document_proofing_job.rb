class DocumentProofingJob < ApplicationJob
  include JobHelpers::FaradayHelper
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    liveness_checking_enabled:,
    image_metadata:,
    analytics_data:
  )
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    dcs = DocumentCaptureSession.find_by(result_id: result_id)
    user = dcs.user

    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )
    document_args = decrypted_args[:document_arguments]
    user_uuid = decrypted_args.fetch(:user_uuid, nil)
    uuid_prefix = decrypted_args.fetch(:uuid_prefix, nil)

    encryption_key = Base64.decode64(document_args[:encryption_key].to_s)
    front_image_iv = Base64.decode64(document_args[:front_image_iv].to_s)
    back_image_iv = Base64.decode64(document_args[:back_image_iv].to_s)
    selfie_image_iv = Base64.decode64(document_args[:selfie_image_iv].to_s)
    front_image_url = document_args[:front_image_url]
    back_image_url = document_args[:back_image_url]
    selfie_image_url = document_args[:selfie_image_url]

    front_image = decrypt_from_s3(
      timer: timer, name: :front, url: front_image_url, iv: front_image_iv, key: encryption_key,
    )
    back_image = decrypt_from_s3(
      timer: timer, name: :back, url: back_image_url, iv: back_image_iv, key: encryption_key,
    )
    if liveness_checking_enabled
      selfie_image = decrypt_from_s3(
        timer: timer, name: :selfie, url: selfie_image_url, iv: selfie_image_iv,
        key: encryption_key
      )
    end

    analytics = build_analytics(dcs)
    doc_auth_client = build_doc_auth_client(analytics, dcs)

    proofer_result = timer.time('proof_documents') do
      with_retries(**faraday_retry_options) do
        doc_auth_client.post_images(
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image || '',
          image_source: image_source(image_metadata),
          liveness_checking_enabled: liveness_checking_enabled,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
        )
      end
    end

    dcs.store_doc_auth_result(
      result: proofer_result.to_h, # pii_from_doc is excluded from to_h to stop accidental logging
      pii: proofer_result.pii_from_doc,
    )

    throttle = Throttle.for(user: user, throttle_type: :idv_doc_auth)

    analytics.track_event(
      Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
      proofer_result.to_h.merge(
        state: proofer_result.pii_from_doc[:state],
        state_id_type: proofer_result.pii_from_doc[:state_id_type],
        async: true,
        attempts: throttle.attempts,
        remaining_attempts: throttle.remaining_count,
        client_image_metrics: image_metadata,
      ).merge(analytics_data),
    )
  ensure
    logger.info(
      {
        name: 'ProofDocument',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      }.to_json,
    )
  end

  private

  def build_analytics(document_capture_session)
    Analytics.new(
      user: document_capture_session.user,
      request: nil,
      sp: document_capture_session.issuer,
      session: {},
    )
  end

  def build_doc_auth_client(analytics, document_capture_session)
    DocAuthRouter.client(
      vendor_discriminator: document_capture_session.uuid,
      warn_notifier: proc { |attrs| analytics.track_event(Analytics::DOC_AUTH_WARNING, attrs) },
    )
  end

  def encryption_helper
    @encryption_helper ||= JobHelpers::EncryptionHelper.new
  end

  def image_source(image_metadata)
    if acuant_sdk_capture?(image_metadata)
      DocAuth::ImageSources::ACUANT_SDK
    else
      DocAuth::ImageSources::UNKNOWN
    end
  end

  def acuant_sdk_capture?(image_metadata)
    image_metadata.dig(:front, :source) == 'acuant' &&
      image_metadata.dig(:back, :source) == 'acuant'
  end

  def s3_helper
    @s3_helper ||= JobHelpers::S3Helper.new
  end

  def decrypt_from_s3(timer:, name:, url:, iv:, key:)
    encrypted_image = timer.time("download.#{name}") do
      if s3_helper.s3_url?(url)
        s3_helper.download(url)
      else
        build_faraday.get(url) do |req|
          req.options.context = { service_name: 'document_proofing_image_download' }
        end.body.b
      end
    end
    timer.time("decrypt.#{name}") do
      encryption_helper.decrypt(data: encrypted_image, iv: iv, key: key)
    end
  end

  # @return [Faraday::Connection] builds a Faraday instance with our defaults
  def build_faraday
    Faraday.new do |conn|
      conn.options.timeout = 3
      conn.options.read_timeout = 3
      conn.options.open_timeout = 3
      conn.options.write_timeout = 3
      conn.request :instrumentation, name: 'request_log.faraday'

      # raises errors on 4XX or 5XX responses
      conn.response :raise_error
    end
  end
end
