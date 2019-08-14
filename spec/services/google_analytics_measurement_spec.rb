require 'rails_helper'

describe GoogleAnalyticsMeasurement do
  describe '#new' do
    let(:category) { 'authentication' }
    let(:event_action) { 'mfa' }
    let(:method) { 'webAuthn' }
    let(:client_id) { 'a68f8374-0970-4c18-92d9-d18ed63ed430' }
    let(:expected_req_body) do
      {
        v: '1',
        tid: Figaro.env.google_analytics_key,
        t: 'event',
        ec: category,
        ea: event_action,
        el: method,
        cid: client_id,
      }
    end

    subject do
      GoogleAnalyticsMeasurement.new(
        category: category,
        event_action: event_action,
        method: method,
        client_id: client_id,
      )
    end

    it 'sends a properly formatted request' do
      url = GoogleAnalyticsMeasurement::GA_URL
      request = stub_request(:post, url).
                with(body: expected_req_body).
                to_return(body: '')

      subject.send_event

      expect(request).to have_been_requested
    end

    it 'catches network connection errors' do
      allow(subject.adapter).to receive(:post).
        and_raise(Faraday::ConnectionFailed.new('error'))

      expect(Rails.logger).to receive(:error)
      subject.send_event
    end

    it 'catches network timeout errors' do
      allow(subject.adapter).to receive(:post).
        and_raise(Faraday::TimeoutError.new('error'))

      expect(Rails.logger).to receive(:error)
      subject.send_event
    end
  end
end
