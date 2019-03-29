require 'rails_helper'

describe GoogleAnalyticsMeasurement do
  describe '#new' do
    let(:category) { 'authenication' }
    let(:event_action) { 'mfa' }
    let(:method) { 'webAuthn' }
    let(:client_id) { 'a68f8374-0970-4c18-92d9-d18ed63ed430' }

    subject do
      GoogleAnalyticsMeasurement.new(
        category: category,
        event_action: event_action,
        method: method,
        client_id: client_id,
      ).send_event
    end

    it 'sends a properly formatted request' do
      expected_req_body = {
        v: 1,
        tid: Figaro.env.ga_uid,
        t: 'event',
        c: category,
        ea: event_action,
        el: method,
        cid: client_id,
      }

      url = GoogleAnalyticsMeasurement::GA_HOST + GoogleAnalyticsMeasurement::GA_COLLECT_ENDPOINT
      request = stub_request(:post, url).
                with(body: expected_req_body).
                to_return(body: '')

      subject.send_event

      expect(request).to have_been_requested
    end
  end
end
