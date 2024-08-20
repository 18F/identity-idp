# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    if token_valid?
      render json: { message: 'Secret token is valid.' }
    else
      render status: :unauthorized, json: { message: 'Invalid secret token.' }
    end
  end

  private

  def token_valid?
    authorization_header = request.headers['Authorization']&.split&.last

    return false if authorization_header.nil?

    ActiveSupport::SecurityUtils.secure_compare(
      authorization_header,
      IdentityConfig.store.socure_webhook_secret_key,
    )
  end
end
