require 'rails_helper'

describe GoogleAnalyticsMeasurement do
  describe '#new' do
    let(:category) { 'authenication' }
    let(:event_action) { 'mfa' }
    let(:method) { 'webAuthn' }
    let(:client_id) { 'a68f8374-0970-4c18-92d9-d18ed63ed430' } do
      GoogleAnalyticsMeasurement.new(
          category: category,
          event_action: event_action,
          method: method,
          client_id: client_id,
      )
    end

    it 'does not raise an error when the response is successful' do
      GoogleAnalyticsMeasurement.adapter = FakeAdapter
      allow(FakeAdapter).to receive(:post).and_return(FakeAdapter::SuccessResponse.new)

      expect { eventSent }.to_not raise_error
    end

  end
end
