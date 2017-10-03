require 'rails_helper'

describe SessionEncryptor do
  describe '#load' do
    it 'decrypts encrypted session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(SessionEncryptor.new.load(session)).to eq('foo' => 'bar')
    end
  end

  it 'makes a round trip okay' do
    encryptor1 = SessionEncryptor.new
    encryptor2 = SessionEncryptor.new

    encryptor1.load(encryptor1.dump('asdf' => '1234'))
    encryptor2.load(encryptor2.dump('asdf' => '1234'))

    payload = { 'hello' => 'world' }
    encrypted_text = encryptor1.dump(payload)
    expect(encryptor2.load(encrypted_text)).to eq(payload)
  end

  it 'does not modify the cek when failing to decrypt a payload encrypted with an old key' do
    old_encryptor = SessionEncryptor.new
    old_encryptor.user_access_key.unlock(Pii::Cipher.random_key)
    old_payload = old_encryptor.dump('asdf' => '1234')

    new_encryptor = SessionEncryptor.new
    original_cek = new_encryptor.user_access_key.cek

    expect { new_encryptor.load(old_payload) }.to raise_error(Pii::EncryptionError)
    expect(new_encryptor.user_access_key.cek).to eq(original_cek)
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
    end
  end
end
