require 'rails_helper'

RSpec.describe TimeService do
  describe '.round_time' do
    it 'returns a Time instance rounded to the nearest interval' do
      time = Time.zone.at(0)

      rounded_time = TimeService.round_time(time:, interval: 5.minutes)
      expect(rounded_time).to eq(time)

      plus_3m_rounded = TimeService.round_time(time: time + 3.minutes, interval: 5.minutes)
      expect(plus_3m_rounded).to eq(time)

      plus_5m_rounded = TimeService.round_time(time: time + 5.minutes, interval: 5.minutes)
      expect(plus_5m_rounded).to_not eq(time)
      expect(plus_5m_rounded.to_i).to eq((time + 5.minutes).to_i)
    end
  end
end
