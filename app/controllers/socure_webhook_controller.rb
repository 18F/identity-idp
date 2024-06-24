# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :verify_authenticity_token

  def create
    # log webhook received referenceID, customerUserId, ...
    body = request.body.read
    parsed_response_body = parse_response_body(body)
    event_type = parsed_response_body.dig('event', 'eventType')
    analytics.socure_webhook(
      event_type: event_type,
      verification_level: IdentityConfig.store.socure_verification_level,
      text: "authorization: #{request.headers['authorization']}", # body,
    )
    webhook = DocAuth::Socure::Webhook.new(parsed_response_body)
    webhook.handle_event
  ensure
    head :ok
  end

  private

  def parse_response_body(body)
    begin
      JSON.parse(body)
    rescue JSON::JSONError
      raise 'failed to parse Socure webhook body'
    end
  end
end
