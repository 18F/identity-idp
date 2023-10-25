# frozen_string_literal: true

module Test
  class TelephonyController < ApplicationController
    layout 'no_card'

    before_action :render_not_found_in_production

    def index
      @messages = Telephony::Test::Message.messages.reverse
      @calls = Telephony::Test::Call.calls.reverse
    end

    def destroy
      Telephony::Test::Message.clear_messages
      Telephony::Test::Call.clear_calls
      redirect_to test_telephony_url
    end

    private

    def render_not_found_in_production
      return unless Rails.env.production?
      render_not_found
    end
  end
end
