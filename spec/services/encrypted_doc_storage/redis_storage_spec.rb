# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EncryptedDocStorage::RedisStorage do
  let(:redis_pool) { REDIS_POOL }
  let(:name) { "encrypted_images/#{SecureRandom.uuid}" }
  let(:encrypted_image) { Encryption::AesCipherV2.new.encrypt("\xFF\xD8binary\x00image", SecureRandom.bytes(32)) }
  let(:ttl_seconds) { 259_200 }

  subject { described_class.new(redis_pool:) }

  before do
    allow(IdentityConfig.store).to receive(:document_images_ttl_seconds).and_return(ttl_seconds)
  end

  after { subject.delete_image(name:) }

  describe '#write_image' do
    it 'stores the payload byte-for-byte with the configured TTL' do
      subject.write_image(encrypted_image:, name:)

      expect(subject.read_image(name:)).to eq(encrypted_image.b)
      expect(subject.ttl(name:)).to be_between(ttl_seconds - 5, ttl_seconds)
    end

    it 'namespaces keys so they cannot collide with other redis-pool data' do
      subject.write_image(encrypted_image:, name:)

      stored_keys = redis_pool.with { |client| client.keys("document-images:#{name}") }
      expect(stored_keys).to eq(["document-images:#{name}"])
    end

    context 'with a shorter configured TTL' do
      let(:ttl_seconds) { 60 }

      it 'honors the configuration' do
        subject.write_image(encrypted_image:, name:)

        expect(subject.ttl(name:)).to be_between(55, 60)
      end
    end
  end

  describe '#read_image' do
    it 'returns nil for a missing or expired object' do
      expect(subject.read_image(name: 'encrypted_images/missing')).to be_nil
    end

    it 'returns a binary-encoded string so the AES payload can be unpacked' do
      subject.write_image(encrypted_image:, name:)

      expect(subject.read_image(name:).encoding).to eq(Encoding::BINARY)
    end
  end

  describe '#delete_image' do
    it 'removes the object' do
      subject.write_image(encrypted_image:, name:)
      subject.delete_image(name:)

      expect(subject.read_image(name:)).to be_nil
      expect(subject.ttl(name:)).to be_nil
    end
  end
end
