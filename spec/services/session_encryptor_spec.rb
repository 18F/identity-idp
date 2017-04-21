require 'rails_helper'

describe SessionEncryptor do
  describe '#load' do
    it 'decrypts encrypted session' do
      session = SessionEncryptor.dump(foo: 'bar')

      expect(SessionEncryptor.load(session)).to eq('foo' => 'bar')
    end

    # rubocop:disable Security/MarshalLoad
    context 'value previously serialized with Marshal and Base64 encoded' do
      it 'decrypts the session and then calls .dump' do
        plain = ::Base64.encode64(Marshal.dump(foo: 'bar'))
        user_access_key = SessionEncryptor.user_access_key
        session = SessionEncryptor.encryptor.encrypt(plain, user_access_key)
        decrypted = SessionEncryptor.encryptor.decrypt(session, user_access_key)
        decoded_session = Marshal.load(::Base64.decode64(decrypted))

        allow(Rails.logger).to receive(:info)
        allow(SessionEncryptor).to receive(:dump)

        expect(SessionEncryptor.load(session)).to eq(foo: 'bar')
        expect(Rails.logger).to have_received(:info).with('Marshalled session found')
        expect(SessionEncryptor).to have_received(:dump).with(decoded_session)
      end
    end
    # rubocop:enable Security/MarshalLoad
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
    end
  end

  describe '#encryptor' do
    it 'is a Pii::Encryptor' do
      expect(SessionEncryptor.encryptor).to be_a Pii::Encryptor
    end
  end
end
