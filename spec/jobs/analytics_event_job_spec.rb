require 'rails_helper'

describe AnalyticsEventJob do
  let(:options) do
    {
      user_agent: 'special_agent',
      user_ip: '127.0.0.1',
      anonymize_ip: true,
      action: 'Authentication Attempt',
      user_id: '771ea225-da0e-48cc-b3af-b9514a02cb42'
    }
  end

  describe '.perform' do
    it 'records an event to Google Analytics' do
      expect(AnalyticsEventJob::TRACKER).to receive(:event).with(options)

      AnalyticsEventJob.perform_now(options)
    end
  end
end
