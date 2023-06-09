# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArcgisApi::TokenKeeper do
  # Faraday::Connection object that uses the test adapter
  let(:connection_factory) { ArcgisApi::ConnectionFactory.new }
  let(:prefetch_ttl) { 1 }
  let(:analytics) { instance_spy(Analytics) }
  let(:subject) do
    obj = described_class.new('test_arcgis_api_token', connection_factory, prefetch_ttl)
    obj.analytics = (analytics)
    obj
  end

  let(:expected) { 'ABCDEFG' }
  let(:expected_sec) { 'GFEDCBA' }
  let(:expires_at) { (Time.zone.now.to_f + 15) * 1000 }
  let(:cache) { Rails.cache }
  before do
    allow(Rails).to receive(:cache).and_return(cache_store)
  end

  shared_examples 'acquire token test' do
    before(:each) do
      Rails.cache.delete(subject.cache_key)
    end
    context 'token not expired and not in prefetch timeframe' do
      it 'get same token at second call' do
        expected = 'ABCDEFG'
        expected_sec = 'GFEDCBA'

        stub_request(:post, %r{/generateToken}).to_return(
          { status: 200,
            body: {
              token: expected,
              expires: (Time.zone.now.to_f + 5) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
          { status: 200,
            body: {
              token: expected_sec,
              expires: (Time.zone.now.to_f + 3600) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
        )

        expect(Rails.cache).to receive(:read).with(kind_of(String)).
          and_call_original
        token = subject.token
        expect(token).to eq(expected)
        sleep(1)
        expect(Rails.cache).to receive(:read).with(kind_of(String)).
          and_call_original
        token = subject.token
        expect(token).to eq(expected)
      end
    end

    context 'token not expired and but in prefetch timeframe' do
      let(:expected) { 'ABCDEFG' }
      let(:expected_sec) { 'GFEDCBA' }
      before(:each) do
        stub_request(:post, %r{/generateToken}).to_return(
          { status: 200,
            body: {
              token: expected,
              expires: (Time.zone.now.to_f + 15) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
          { status: 200,
            body: {
              token: expected_sec,
              expires: (Time.zone.now.to_f + 3600) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
        )
      end
      let(:prefetch_ttl) do
        5
      end
      context 'get token at different timing' do
        it 'get same token between sliding_expires_at passed and sliding_expires_at+prefetch_ttl' do
          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected)
          sleep(1)
          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected)
        end
        it 'regenerates token when passed sliding_expires_at+prefetch_ttl' do
          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected)
          sleep(11)
          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected_sec)
        end
      end
    end

    context 'value only token in cache' do
      let(:expected) { 'ABCDEFG' }
      let(:expected_sec) { 'GFEDCBA' }
      before(:each) do
        stub_request(:post, %r{/generateToken}).to_return(
          { status: 200,
            body: {
              token: expected,
              expires: (Time.zone.now.to_f + 15) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
        )
        subject.save_token(expected, expires_at)
      end
      let(:prefetch_ttl) do
        5
      end
      it 'should use deal with the value only token' do
        token = subject.token
        expect(token).to eq(expected)
      end
    end
  end
  context 'with in memory store' do
    let(:cache_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    context 'sliding expiration enabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:arcgis_token_sliding_expiration_enabled).
          and_return(true)
      end
      include_examples 'acquire token test'
    end
  end
  context 'with redis store' do
    let(:cache_store) { ActiveSupport::Cache.lookup_store(:redis_cache_store) }
    include_examples 'acquire token test'
    context 'retry options' do
      it 'retry remote request multiple times as needed and emit analytics events' do
        stub_request(:post, %r{/generateToken}).to_return(
          {
            status: 403,
          },
          {
            status: 200,
            body: ArcgisApi::Mock::Fixtures.request_token_service_error,
            headers: { content_type: 'application/json;charset=UTF-8' },
          },
          {
            status: 200,
            body: ArcgisApi::Mock::Fixtures.invalid_gis_token_credentials_response,
            headers: { content_type: 'application/json;charset=UTF-8' },
          },
          { status: 200,
            body: {
              token: expected,
              expires: (Time.zone.now.to_f + 3600) * 1000,
              ssl: true,
            }.to_json,
            headers: { content_type: 'application/json;charset=UTF-8' } },
        )
        token = subject.fetch_save_token!
        expect(token.fetch(:token)).to eq(expected)
        expect(analytics).to have_received(:idv_arcgis_request_failure).exactly(3).times
      end
    end
    context 'token sync request disabled' do
      it 'does not fetch token' do
        allow(IdentityConfig.store).to receive(:arcgis_token_sync_request_enabled).and_return(false)
        expect(subject.token).to be(nil)
      end
    end
  end
end
