require 'rails_helper'

RSpec.describe UtcTimePresenter do
  describe '#to_s' do
    it 'returns the formatted timestamp in a string' do
      timestamp = Time.use_zone('UTC') do
        str = '2017-04-12 18:19:18'
        Time.zone.parse(str)
      end

      expect(UtcTimePresenter.new(timestamp).to_s).to eq(
        'April 12, 2017 at 6:19 PM',
      )
    end
  end
end
