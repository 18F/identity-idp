# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureReasonCodeDownloadJob do
  subject(:job) { described_class.new }

  let(:idv_socure_reason_code_download_enabled) { true }
  let(:analytics) { FakeAnalytics.new }

  let(:api_response_body) do
    {
      'reasonCodes' => {
        'ProductA' => {
          'A1' => 'test1',
          'A2' => 'test2',
        },
        'ProductB' => {
          'B2' => 'test3',
        },
      },
    }.to_json
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_socure_reason_code_download_enabled)
      .and_return(idv_socure_reason_code_download_enabled)
    allow(IdentityConfig.store).to receive(:socure_reason_code_base_url)
      .and_return('https://example.org')
  end

  describe '#perform' do
    it 'downloads reason codes and writes them to the database' do
      stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: api_response_body,
      )

      expect { job.perform }.to change { SocureReasonCode.count }.from(0).to(3)
    end

    it 'logs an analytics event' do
      allow(job).to receive(:analytics).and_return(analytics)
      stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: api_response_body,
      )

      job.perform

      expect(analytics).to have_logged_event(
        :idv_socure_reason_code_download,
        success: true,
        added_reason_codes: [
          { 'code' => 'A1', 'group' => 'ProductA', 'description' => 'test1' },
          { 'code' => 'A2', 'group' => 'ProductA', 'description' => 'test2' },
          { 'code' => 'B2', 'group' => 'ProductB', 'description' => 'test3' },
        ],
        deactivated_reason_codes: [],
      )
    end

    context 'when an error occurs downloading the codes' do
      it 'logs the error' do
        allow(job).to receive(:analytics).and_return(analytics)
        stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_timeout

        expect { job.perform }.to_not change { SocureReasonCode.count }

        expect(analytics).to have_logged_event(
          :idv_socure_reason_code_download,
          success: false,
          exception: a_string_matching(/execution expired/),
        )
      end
    end

    context 'when the job is disabled' do
      let(:idv_socure_reason_code_download_enabled) { false }

      it 'does not download codes and does not write anything to the database' do
        allow(job).to receive(:analytics).and_return(analytics)
        api_response_body = { 'reasonCodes' => { 'A1' => 'test1', 'B2' => 'test2' } }.to_json
        stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
          headers: { 'Content-Type' => 'application/json' },
          body: api_response_body,
        )

        expect { job.perform }.to_not change { SocureReasonCode.count }
      end
    end
  end
end
