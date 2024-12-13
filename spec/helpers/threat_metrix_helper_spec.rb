require 'rails_helper'

RSpec.describe ThreatMetrixHelper do
  include ThreatMetrixHelper

  describe '#threatmetrix_javascript_urls' do
    let(:session_id) { '1234' }
    before do
      allow(IdentityConfig.store)
        .to receive(:lexisnexis_threatmetrix_org_id)
        .and_return('test_id')

      allow(Rails.application.config.asset_sources).to receive(:get_sources)
        .with('mock-device-profiling').and_return(['/mock-device-profiling.js'])
    end
    context 'mock is enabled' do
      before do
        allow(IdentityConfig.store)
          .to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(true)
      end
      it 'should return mock config source' do
        sources = threatmetrix_javascript_urls(session_id)
        expect(sources).to eq(['/mock-device-profiling.js?org_id=test_id&session_id=1234'])
      end
    end
    context 'mock is not enabled' do
      before do
        allow(IdentityConfig.store)
          .to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(false)
      end
      it 'should return actual url' do
        javascript_sources = threatmetrix_javascript_urls(session_id)
        expect(javascript_sources)
          .to eq(['https://h.online-metrix.net/fp/tags.js?org_id=test_id&session_id=1234'])
      end
    end
  end

  describe '#threatmetrix_iframe_url' do
    let(:session_id) { '1234' }
    before do
      allow(IdentityConfig.store)
        .to receive(:lexisnexis_threatmetrix_org_id)
        .and_return('test_id')

      allow(Rails.application.config.asset_sources).to receive(:get_sources)
        .with('mock-device-profiling').and_return(['/mock-device-profiling.js'])
    end
    context 'mock is enabled' do
      before do
        allow(IdentityConfig.store)
          .to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(true)
      end
      it 'should return mock javascript config' do
        iframe_sources = threatmetrix_iframe_url(session_id)
        expect(iframe_sources)
          .to eq('http://www.example.com/test/device_profiling?org_id=test_id&session_id=1234')
      end
    end

    context 'mock is not enabled' do
      before do
        allow(IdentityConfig.store)
          .to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(false)
      end
      it 'should return mock config source' do
        iframe_sources = threatmetrix_iframe_url(session_id)
        expect(iframe_sources)
          .to eq('https://h.online-metrix.net/fp/tags?org_id=test_id&session_id=1234')
      end
    end
  end
end
