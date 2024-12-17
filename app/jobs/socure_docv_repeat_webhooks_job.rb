# frozen_string_literal: true

class SocureDocvRepeatWebhooksJob < ApplicationJob
  queue_as :high_socure_docv

  def perform(body:, headers:, endpoint:)
    wr = DocAuth::Socure::WebhookRepeater.new(body:, headers:, endpoint:)
    wr.repeat
  end
end
