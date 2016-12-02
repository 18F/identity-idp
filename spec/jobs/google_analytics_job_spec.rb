require 'rails_helper'

describe GoogleAnalyticsJob do
  describe '.perform' do
    it 'calls Staccato tracker' do
      tracker = instance_double(Staccato::NoopTracker)
      allow(Staccato).to receive(:tracker).with(nil, nil, ssl: true).and_return(tracker)

      expect(tracker).to receive(:event).with(action: '1234')

      GoogleAnalyticsJob.perform_now(event_name: '1234')
    end
  end
end
