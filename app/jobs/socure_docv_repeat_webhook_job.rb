# frozen_string_literal: true

class SocureDocvRepeatWebhookJob < ApplicationJob
  queue_as :high_socure_docv

  # @param encrypted_arguments [String] the webhook body and headers as one JSON object,
  #   `{ body:, headers: }`, encrypted by the controller with BackgroundProofingArgEncryptor so the
  #   webhook secret in the Authorization header is never stored in clear text with the job
  # @param endpoint [String] the URL that receives the repeated webhook
  def perform(encrypted_arguments:, endpoint:)
    arguments = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )
    wr = DocAuth::Socure::WebhookRepeater.new(
      body: arguments[:body],
      headers: arguments[:headers],
      endpoint:,
    )
    wr.repeat
  end
end
