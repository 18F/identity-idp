require 'rails_helper'
RSpec.describe IrsAttemptsApi::EnvelopeEncryptor do
  let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
  let(:public_key) { private_key.public_key }
  describe '.encrypt' do
    it 'returns encrypted result' do
      text = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
      time = Time.zone.now
      result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
        data: text, timestamp: time, public_key: public_key,
      )

      expect(result.encrypted_data).to_not eq text
      expect(result.encrypted_data).to_not include(text)
      expect(Base16.decode16(result.encrypted_data)).to_not include(text)
    end

    it 'filename includes digest and truncated timestamp' do
      text = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
      time = Time.zone.now
      result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
        data: text, timestamp: time,
        public_key: public_key
      )
      digest = Digest::SHA256.hexdigest(result.encrypted_data)

      expect(result.filename).to include(
        IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(time),
      )
      expect(result.filename).to include(digest)
    end
  end

  describe '.decrypt' do
    it 'returns decrypted text' do
      text = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
      time = Time.zone.now
      result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
        data: text, timestamp: time,
        public_key: public_key
      )
      key = private_key.private_decrypt(result.encrypted_key)

      expect(
        IrsAttemptsApi::EnvelopeEncryptor.decrypt(
          encrypted_data: result.encrypted_data,
          key: key,
          iv: result.iv,
        ),
      ).to eq(text)
    end
  end

  describe '.formatted_timestamp' do
    it 'formats according to the specification' do
      timestamp = Time.new(2022, 1, 1, 11, 1, 1, 'UTC')
      result = IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(timestamp)

      expect(result).to eq '20220101T11Z'
    end
  end
end
