class DocumentProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    image_metadata:,
    analytics_data:,
    flow_path:
  )
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    dcs = DocumentCaptureSession.find_by(result_id: result_id)
    user = dcs.user

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )
    document_args = decrypted_args[:document_arguments]
    user_uuid = decrypted_args.fetch(:user_uuid, nil)
    uuid_prefix = decrypted_args.fetch(:uuid_prefix, nil)

    encryption_key = Base64.decode64(document_args[:encryption_key].to_s)
    front_image_iv = Base64.decode64(document_args[:front_image_iv].to_s)
    back_image_iv = Base64.decode64(document_args[:back_image_iv].to_s)
    front_image_url = document_args[:front_image_url]
    back_image_url = document_args[:back_image_url]

    front_image = decrypt_image_from_s3(
      timer: timer, name: :front, url: front_image_url, iv: front_image_iv, key: encryption_key,
    )
    back_image = decrypt_image_from_s3(
      timer: timer, name: :back, url: back_image_url, iv: back_image_iv, key: encryption_key,
    )

    analytics = build_analytics(dcs)
    doc_auth_client = build_doc_auth_client(analytics, dcs)

    proofer_result = timer.time('proof_documents') do
      doc_auth_client.post_images(
        front_image: front_image,
        back_image: back_image,
        image_source: image_source(image_metadata),
        user_uuid: user_uuid,
        uuid_prefix: uuid_prefix,
      )
    end

    dcs.store_doc_auth_result(
      result: proofer_result.to_h, # pii_from_doc is excluded from to_h to stop accidental logging
      pii: proofer_result.pii_from_doc,
    )

    throttle = Throttle.new(user: user, throttle_type: :idv_doc_auth)

    # ToDo: Update this with Lexis Nexis workflow
    analytics.idv_doc_auth_submitted_image_upload_vendor(
      **proofer_result.to_h.merge(
        state: proofer_result.pii_from_doc[:state],
        state_id_type: proofer_result.pii_from_doc[:state_id_type],
        async: true,
        attempts: throttle.attempts,
        remaining_attempts: throttle.remaining_count,
        client_image_metrics: image_metadata,
        flow_path: flow_path,
        vendor_workflow: image_source.image_metadata.to_s,
      ).merge(analytics_data).
        merge(native_camera_ab_test_data(dcs)),
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

  def native_camera_ab_test_data(document_capture_session)
    return {} unless IdentityConfig.store.idv_native_camera_a_b_testing_enabled

    {
      native_camera_ab_test_bucket: AbTests::NATIVE_CAMERA.bucket(document_capture_session.uuid),
    }
  end

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
      warn_notifier: proc { |attrs| analytics.doc_auth_warning(**attrs) },
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

  def normalize_image_file(file_or_data_url)
    return file_or_data_url if !file_or_data_url.start_with?('data:')

    data_url_image = Idv::DataUrlImage.new(file_or_data_url)
    data_url_image.read
  rescue Idv::DataUrlImage::InvalidUrlFormatError
    file_or_data_url
  end

  def acuant_sdk_capture?(image_metadata)
    image_metadata.dig(:front, :source) == Idp::Constants::Vendors::ACUANT &&
      image_metadata.dig(:back, :source) == Idp::Constants::Vendors::ACUANT
  end

  def s3_helper
    @s3_helper ||= JobHelpers::S3Helper.new
  end

  def decrypt_image_from_s3(timer:, name:, url:, iv:, key:)
    encrypted_image = timer.time("download.#{name}") do
      if s3_helper.s3_url?(url)
        s3_helper.download(url)
      else
        build_faraday.get(url) do |req|
          req.options.context = { service_name: 'document_proofing_image_download' }
        end.body.b
      end
    end
    decrypted = timer.time("decrypt.#{name}") do
      encryption_helper.decrypt(data: encrypted_image, iv: iv, key: key)
    end
    timer.time("decode.#{name}") do
      normalize_image_file(decrypted)
    end
  end

  # @return [Faraday::Connection] builds a Faraday instance with our defaults
  def build_faraday
    Faraday.new do |conn|
      conn.options.timeout = IdentityConfig.store.doc_auth_s3_request_timeout
      conn.options.read_timeout = IdentityConfig.store.doc_auth_s3_request_timeout
      conn.options.open_timeout = IdentityConfig.store.doc_auth_s3_request_timeout
      conn.options.write_timeout = IdentityConfig.store.doc_auth_s3_request_timeout
      conn.request :instrumentation, name: 'request_log.faraday'

      # raises errors on 4XX or 5XX responses
      conn.response :raise_error
    end
  end
end
