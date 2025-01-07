require 'rails_helper'

RSpec.describe OpenidConnectKeyValidation do
  let(:private_key) { OpenSSL::PKey::RSA.generate(1_024) }

  describe '#valid?' do
    it 'returns true for a valid public/private key pair' do
      public_key = private_key.public_key
      valid = OpenidConnectKeyValidation.valid?(
        private_key: private_key,
        public_key: public_key,
        data: '123',
      )

      expect(valid).to eq(true)
    end

    it 'returns false for a invalid pair' do
      other_private_key = OpenSSL::PKey::RSA.generate(1_024)
      public_key = private_key.public_key
      valid = OpenidConnectKeyValidation.valid?(
        private_key: other_private_key,
        public_key: public_key,
        data: '123',
      )

      expect(valid).to eq(false)
    end

    it 'raises an error if private key and public key are swapped' do
      public_key = private_key.public_key
      expect do
        OpenidConnectKeyValidation.valid?(
          private_key: public_key,
          public_key: private_key,
          data: '123',
        ).to raise_error(RuntimeError.new('private key is needed'))
      end
    end
  end
end
