require 'rails_helper'

describe UtcTimePresenter do
  describe '#to_s' do
    it 'returns the formatted timestamp in a string' do
      str = '2017-04-12 18:19:18 UTC'
      timestamp = Time.parse(str)

      expect(UtcTimePresenter.new(timestamp).to_s).to eq(
        'April 12, 2017 at 6:19 PM UTC'
      )
    end
  end
end
