require 'rails_helper'

describe Encryption::MultiRegionKmsClient do
  let(:kms_enabled) { true }
  let(:kms_multi_region_enabled) { true }
  let(:aws_kms_regions) { %w[us-north-1 us-south-1] }
  let(:aws_region) { 'us-north-1' }

  before do
    stub_const(
      'Encryption::MultiRegionKmsClient::KMS_REGION_CLIENT_POOL',
      Hash.new do |h, region|
        h[region] = FakeConnectionPool.new { Aws::KMS::Client.new(region: region) }
      end,
    )

    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
    allow(FeatureManagement).to receive(:kms_multi_region_enabled?).
      and_return(kms_multi_region_enabled)
    allow(IdentityConfig.store).to receive(:aws_kms_regions).and_return(aws_kms_regions)
    allow(IdentityConfig.store).to receive(:aws_region).and_return(aws_region)

    stub_mapped_aws_kms_client(
      [
        { plaintext: plaintext, ciphertext: 'k1:us-north-1', key_id: 'key1', region: 'us-north-1' },
        { plaintext: plaintext, ciphertext: 'k1:us-south-1', key_id: 'key1', region: 'us-south-1' },
      ],
    )
  end

  let(:plaintext) { 'a' * 3000 }
  let(:encryption_context) { { 'context' => 'attribute-bundle', 'user_id' => '123-abc-456-def' } }

  let(:regionalized_kms_ciphertext) do
    {
      regions: {
        'us-north-1' => Base64.strict_encode64('k1:us-north-1'),
        'us-south-1' => Base64.strict_encode64('k1:us-south-1'),
      },
    }.to_json
  end

  let(:legacy_kms_ciphertext) { 'k1:us-north-1' }

  describe '#encrypt' do
    let(:aws_key_id) { 'key1' }

    context 'with multi region enabled' do
      it 'encrypts with KMS' do
        result = subject.encrypt(aws_key_id, plaintext, encryption_context)
        expect(result).to eq(regionalized_kms_ciphertext)
      end
    end
    context 'with multi region disabled' do
      let(:kms_multi_region_enabled) { false }
      it 'encrypts with KMS' do
        result = subject.encrypt(aws_key_id, plaintext, encryption_context)
        expect(result).to eq(legacy_kms_ciphertext)
      end
    end
  end

  describe '#decrypt' do
    context 'with a multi region ciphertext' do
      it 'decrypts the ciphertext with KMS' do
        result = subject.decrypt(regionalized_kms_ciphertext, encryption_context)
        expect(result).to eq(plaintext)
      end
    end

    context 'with a legacy ciphertext' do
      it 'decrypts the ciphertext with KMS' do
        result = subject.decrypt(legacy_kms_ciphertext, encryption_context)
        expect(result).to eq(plaintext)
      end
    end

    it 'decrypts successfully if the default region is not present' do
      non_default_ciphertext = {
        regions: { 'us-north-1' => Base64.strict_encode64('k1:us-north-1') },
      }.to_json
      result = subject.decrypt(non_default_ciphertext, encryption_context)
      expect(result).to eq(plaintext)
    end

    it 'errors if none of the encryption regions are present' do
      bad_region_ciphertext = {
        regions: {
          foo: 'kms1',
          bar: 'kms2',
        },
      }.to_json
      expect do
        subject.decrypt(bad_region_ciphertext, encryption_context)
      end.to raise_error(Encryption::EncryptionError)
    end

    it 'decrypts successfully if only one of the encryption regions is valid' do
      partially_valid_ciphertext = {
        regions: {
          foo: 'kms1',
          'us-south-1': Base64.strict_encode64('k1:us-south-1'),
        },
      }.to_json
      result = subject.decrypt(partially_valid_ciphertext, encryption_context)
      expect(result).to eq(plaintext)
    end

    it 'decrypts in default region where multiple regions present' do
      multi_region_ciphertext = {
        regions: {
          'us-north-1': Base64.strict_encode64('k1:us-north-1'),
          'us-south-1': Base64.strict_encode64('k1:us-south-1'),
        },
      }.to_json
      result = subject.decrypt(multi_region_ciphertext, encryption_context)
      expect(result).to eq(plaintext)
    end
  end
end
