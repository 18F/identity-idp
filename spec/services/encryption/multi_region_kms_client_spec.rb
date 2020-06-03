require 'rails_helper'

describe Encryption::MultiRegionKMSClient do
  before do
    stub_mapped_aws_kms_client(
      'a' * 3000 => 'kms1',
    )

    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
  end

  let(:plaintext) { 'a' * 3000 }
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
        result = subject.encrypt(aws_key_id, plaintext, encryption_context)
        expect(result).to eq(regionalized_kms_ciphertext)
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

  end
end
