# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :verify_authenticity_token

  def create
    # log webhook received referenceID, customerUserId, ...
    if token_valid?
      body = request.body.read
      parsed_response_body = parse_response_body(body)
      event_type = parsed_response_body.dig('event', 'eventType')

      analytics.socure_webhook(
        event_type: event_type,
        verification_level: IdentityConfig.store.socure_verification_level,
        text: '', # body
      )
      webhook = DocAuth::Socure::Webhook.new(parsed_response_body)
      webhook.handle_event
    end
  ensure
    head token_valid? ? :ok : :not_found
  end

  private

  def token_valid?
    request.headers['authorization'] == IdentityConfig.store.socure_webhook_secret_key
  end

  def parse_response_body(body)
    begin
      JSON.parse(body)
    rescue JSON::JSONError
      raise 'failed to parse Socure webhook body'
    end
  end
end
