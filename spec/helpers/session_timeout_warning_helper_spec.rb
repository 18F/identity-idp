require 'rails_helper'

describe SessionTimeoutWarningHelper do
  describe '#time_left_in_session' do
    it 'describes time left based on when the timeout warning appears' do
      allow(Figaro.env).
        to receive(:session_check_frequency).and_return(1.minute)
      allow(Figaro.env).
        to receive(:session_check_delay).and_return(2.minutes)
      allow(Figaro.env).
        to receive(:session_timeout_warning_seconds).and_return(3.minutes)

      expect(helper.time_left_in_session).
        to eq distance_of_time_in_words(time_between_warning_and_timeout)
    end
  end
end

def time_between_warning_and_timeout
  Figaro.env.session_timeout_warning_seconds
end
