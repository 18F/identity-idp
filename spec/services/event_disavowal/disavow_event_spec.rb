require 'rails_helper'

describe EventDisavowal::DisavowEvent do
  describe '#call' do
    it 'sets disavowed_at' do
      event = create(:event, disavowed_at: nil)
      described_class.new(event).call

      expect(event.reload.disavowed_at).to be_within(1).of(Time.zone.now)
    end
  end
end
