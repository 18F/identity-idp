require 'rails_helper'

describe Encryption::MultiRegionKMSClient do
  let(:kms_enabled) { true }
  let(:kms_multi_region_enabled) { true }
  let(:kms_region_configs) do
    [
      { region: 'us-north-by-northwest-1', key_id: 'key1' },
      { region: 'us-south-by-southwest-1', key_id: 'key2' },
    ]
  end
  let(:aws_region) { 'us-north-by-northwest-1' }

  before do
    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
    allow(FeatureManagement).to receive(:kms_multi_region_enabled?).
      and_return(kms_multi_region_enabled)
    allow(Figaro.env).to receive(:aws_kms_region_configs).and_return(kms_region_configs.to_json)
    allow(Figaro.env).to receive(:aws_region).and_return(aws_region)

    stub_mapped_aws_kms_client(
      [
        { plaintext: plaintext, ciphertext: 'key1:kms1', key_id: 'key1' },
        { plaintext: plaintext, ciphertext: 'key2:kms1', key_id: 'key2' },
      ],
    )
  end

  let(:plaintext) { 'a' * 3000 }
  let(:encryption_context) { { 'context' => 'attribute-bundle', 'user_id' => '123-abc-456-def' } }

  let(:regionalized_kms_ciphertext) do
    {
      regions: {
        'us-north-by-northwest-1' => Base64.strict_encode64('key1:kms1'),
        'us-south-by-southwest-1' => Base64.strict_encode64('key2:kms1'),
      },
    }.to_json
  end

  let(:legacy_kms_ciphertext) { 'key1:kms1' }

  let(:aws_key_id) { Figaro.env.aws_kms_key_id }

  describe '#encrypt' do
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
        regions: { 'us-north-by-northwest-1' => Base64.strict_encode64('key2:kms1') },
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
          'us-south-by-southwest-1': Base64.strict_encode64('key2:kms1'),
        },
      }.to_json
      result = subject.decrypt(partially_valid_ciphertext, encryption_context)
      expect(result).to eq(plaintext)
    end

    it 'decrypts in default region where multiple regions present' do
      multi_region_ciphertext = {
        regions: {
          'us-north-by-northwest-1': Base64.strict_encode64('key1:kms1'),
          'us-south-by-southwest-1': Base64.strict_encode64('key2:kms1'),
        },
      }.to_json
      result = subject.decrypt(multi_region_ciphertext, encryption_context)
      expect(result).to eq(plaintext)
    end
  end
end
