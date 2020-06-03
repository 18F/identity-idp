require 'rails_helper'

describe Encryption::MultiRegionKMSClient do
  before do
    stub_mapped_aws_kms_client(
      'a' * 3000 => 'kms1',
      'b' * 3000 => 'kms2',
    )

    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
  end

  let(:first_plaintext) { 'a' * 3000 }
  let(:second_plaintext) { 'b' * 3000 }
  let(:encryption_context) { { 'context' => 'attribute-bundle', 'user_id' => '123-abc-456-def' } }

  kms_regions = JSON.parse(Figaro.env.aws_kms_regions)

  let(:regionalized_kms_ciphertext) do
    region_hash = {}
    kms_regions.each do |r|
      region_hash[r] = 'kms1'
    end
    { regions: region_hash }.to_json
  end

  let(:legacy_kms_ciphertext) do
    'kms1'
  end

  let(:kms_enabled) { true }

  aws_key_id = Figaro.env.aws_kms_key_id

  describe '#encrypt' do
    context 'with multi region enabled' do
      it 'encrypts with KMS' do
        result = subject.encrypt(aws_key_id, first_plaintext, encryption_context)
        expect(result).to eq(regionalized_kms_ciphertext)
      end
    end


  end

  describe '#decrypt' do
    context 'with a multi region ciphertext' do
      it 'decrypts the ciphertext with KMS' do
        result = subject.decrypt(regionalized_kms_ciphertext, encryption_context)
        expect(result).to eq(first_plaintext)
      end
    end

    context 'with a legacy ciphertext' do
      it 'decrypts the ciphertext with KMS' do
        result = subject.decrypt(legacy_kms_ciphertext, encryption_context)
        expect(result).to eq(first_plaintext)
      end
    end

    it 'decrypts successfully if the default region is not present' do
      non_default_ciphertext = {
        regions: { 'us-east-1' => 'kms1' },
      }.to_json
      result = subject.decrypt(non_default_ciphertext, encryption_context)
      expect(result).to eq(first_plaintext)
    end

    it 'decrypts unsuccessfully if none of the encryption regions are present' do
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
          'us-west-2': 'kms2',
        },
      }.to_json
      result = subject.decrypt(partially_valid_ciphertext, encryption_context)
      expect(result).to eq(second_plaintext)
    end

    it 'decrypts in default region where multiple regions present' do
      # At the moment, 'us-east-1' is the default AWS region for testing in application.yml.
      # This test will fail if that changes, make sure to update accordingly
      multi_region_ciphertext = {
        regions: {
          'us-east-1': 'kms1',
          'us-west-2': 'kms2',
        },
      }.to_json
      result = subject.decrypt(multi_region_ciphertext, encryption_context)
      expect(result).to eq(first_plaintext)
    end
  end
end
