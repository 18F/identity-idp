require 'rails_helper'

RSpec.describe IrsAttemptsApi::Encryptor do
  let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
  let(:public_key) { private_key.public_key }
  describe '#encrypt' do
    it 'returns encrypted result' do
      text = 'test'
      time = Time.zone.now
      result = IrsAttemptsApi::Encryptor.encrypt(
        data: text, timestamp: time,
        public_key: public_key
      )

      expect(result.encrypted_data).to_not eq text
    end

    it 'filename includes digest and truncated timestamp' do
      text = 'test'
      time = Time.zone.now
      result = IrsAttemptsApi::Encryptor.encrypt(
        data: text, timestamp: time,
        public_key: public_key
      )
      digest = Digest::SHA256.hexdigest(result.encrypted_data)

      expect(result.filename).to include(IrsAttemptsApi::Encryptor.formatted_timestamp(time))
      expect(result.filename).to include(digest)
    end
  end

  describe '#decrypt' do
    it 'returns decrypted text' do
      text = 'test'
      time = Time.zone.now
      result = IrsAttemptsApi::Encryptor.encrypt(
        data: text, timestamp: time,
        public_key: public_key
      )
      key = private_key.private_decrypt(result.encrypted_key)

      expect(
        IrsAttemptsApi::Encryptor.decrypt(
          encrypted_data: result.encrypted_data,
          key: key,
          iv: result.iv,
        ),
      ).to eq(text)
    end
  end
end
