# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArcgisApi::TokenUtil do

  # Faraday::Connection object that uses the test adapter
  let(:conn) { ArcgisApi::ConnectionFactory.new.connection }
  let(:prefetch_ttl) { 1 }
  let(:subject) { described_class.new(conn, prefetch_ttl) }

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
        # set expiring in 5 seconds
        expires_at = (Time.zone.now.to_f + 5) * 1000

        stub_request(:post, %r{/generateToken}).to_return(
          { status: 200,
            body: {
              token: expected,
              expires: expires_at,
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
      let(:expires_at) { (Time.zone.now.to_f + 15) * 1000 }
      before(:each) do
        stub_request(:post, %r{/generateToken}).to_return(
          { status: 200,
            body: {
              token: expected,
              expires: expires_at,
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

        it 'get cached token when sliding_expires_at passed but still with in sliding_expires_at+prefetch_ttl' do

          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected)
          sleep(6)
          expect(Rails.cache).to receive(:read).with(kind_of(String)).
            and_call_original
          token = subject.token
          expect(token).to eq(expected)
        end
        it 'regenerate token when sliding_expires_at passed and also passed sliding_expires_at+prefetch_ttl' do
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
  end
  context 'with in memory store' do
    let(:cache_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    include_examples 'acquire token test'
  end
  context 'with redis store' do
    let(:cache_store) { ActiveSupport::Cache.lookup_store(:redis_cache_store) }
    include_examples 'acquire token test'
  end
end
