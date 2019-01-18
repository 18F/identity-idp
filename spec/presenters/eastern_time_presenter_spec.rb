require 'rails_helper'

describe EasternTimePresenter do
  describe '#to_s' do
    it 'returns the formatted timestamp in a string' do
      str = '2017-04-12 18:19:18 UTC'
      timestamp = Time.zone.parse(str)

      expect(EasternTimePresenter.new(timestamp).to_s).to eq(
        'April 12, 2017 at 2:19 PM (Eastern)',
      )
    end
  end
end
