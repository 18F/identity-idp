module Test
  class TelephonyController < ApplicationController
    layout 'card_wide'

    before_action :render_not_found_in_production

    def index
      @messages = Telephony::Test::Message.messages.reverse
      @calls = Telephony::Test::Call.calls.reverse
    end

    private

    def render_not_found_in_production
      return unless Rails.env.production?
      render_not_found
    end
  end
end
