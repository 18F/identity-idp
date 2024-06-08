# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :verify_authenticity_token

  def create
    # log webhook received referenceID, customerUserId, ...
    webhook = SocureWebhook.new(parsed_response_body)
    webhook.handle_event
  ensure
    head :ok
  end

  private

  def parsed_response_body
    begin
      JSON.parse(request.body.read)
    rescue JSON::JSONError
      raise 'failed to parse Socure webhook body'
    end
  end
end
