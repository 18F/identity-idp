require 'base64'
require 'faraday'
require 'identity-doc-auth'
require 'json'
require 'retries'

module IdentityIdpFunctions
  class ProofDocument
    include IdentityIdpFunctions::FaradayHelper

    attr_reader :encryption_key, :front_image_iv, :back_image_iv, :selfie_image_iv,
                :front_image_url, :back_image_url, :selfie_image_url,
                :liveness_checking_enabled, :trace_id, :logger, :timer

    alias_method :liveness_checking_enabled?, :liveness_checking_enabled

    def initialize(encryption_key:,
                   front_image_iv:,
                   back_image_iv:,
                   selfie_image_iv:,
                   front_image_url:,
                   back_image_url:,
                   selfie_image_url:,
                   liveness_checking_enabled:,
                   logger:,
                   trace_id: nil)
      @encryption_key = Base64.decode64(encryption_key.to_s)
      @front_image_iv = Base64.decode64(front_image_iv.to_s)
      @back_image_iv = Base64.decode64(back_image_iv.to_s)
      @selfie_image_iv = Base64.decode64(selfie_image_iv.to_s)
      @front_image_url = front_image_url
      @back_image_url = back_image_url
      @selfie_image_url = selfie_image_url
      @liveness_checking_enabled = liveness_checking_enabled
      @logger = logger
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof
      front_image = decrypt_from_s3(:front, front_image_url, front_image_iv)
      back_image = decrypt_from_s3(:back, back_image_url, back_image_iv)
      selfie_image = if liveness_checking_enabled?
                       decrypt_from_s3(:selfie, selfie_image_url, selfie_image_iv)
                     end

      proofer_result = timer.time('proof_documents') do
        with_retries(**faraday_retry_options) do
          doc_auth_client.post_images(
            front_image: front_image,
            back_image: back_image,
            selfie_image: selfie_image || '',
            liveness_checking_enabled: liveness_checking_enabled?,
          )
        end
      end

      # pii_from_doc is excluded from to_h to prevent accidental logging
      result = proofer_result.to_h.merge(pii_from_doc: proofer_result.pii_from_doc)

      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      {
        document_result: result,
      }
    ensure
      logger.info(
        name: 'ProofDocument',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      )
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuthRouter.client
    end

    def encryption_helper
      @encryption_helper ||= EncryptionHelper.new
    end

    def s3_helper
      @s3_helper ||= S3Helper.new
    end

    def decrypt_from_s3(name, url, iv)
      encrypted_image = timer.time("download.#{name}") { s3_helper.download(url) }
      timer.time("decrypt.#{name}") do
        encryption_helper.decrypt(data: encrypted_image, iv: iv, key: encryption_key)
      end
    end
  end
end
