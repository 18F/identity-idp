module Test
  class TelephonyController < ApplicationController
    layout 'card_wide'

    def index
      @messages = Telephony::Test::Message.messages.reverse
      @calls = Telephony::Test::Call.calls.reverse
    end
  end
end
