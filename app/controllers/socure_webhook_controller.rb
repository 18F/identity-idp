#frozen_string_literal: true

class SocureWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def on_event
    puts "got here."

    render json: { message: 'Got here.' }
  end
end
