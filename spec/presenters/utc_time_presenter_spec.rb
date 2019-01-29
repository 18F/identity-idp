require 'rails_helper'

describe UtcTimePresenter do
  describe '#to_s' do
    it 'returns the formatted timestamp in a string' do
      current_timezone = Time.zone
      Time.zone = 'UTC'
      str = '2017-04-12 18:19:18'
      timestamp = Time.zone.parse(str)
      Time.zone = current_timezone

      expect(UtcTimePresenter.new(timestamp).to_s).to eq(
        'April 12, 2017 at 6:19 PM',
      )
    end
  end
end
