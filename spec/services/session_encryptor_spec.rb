require 'rails_helper'

describe SessionEncryptor do
  describe '#load' do
    it 'decrypts encrypted session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(SessionEncryptor.new.load(session)).to eq('foo' => 'bar')
    end
  end

  it 'makes a roundtrip okay across separate instances' do
    encryptor1 = SessionEncryptor.new
    encryptor2 = SessionEncryptor.new

    encryptor1.load(encryptor1.dump('asdf' => '1234'))
    encryptor2.load(encryptor2.dump('asdf' => '1234'))

    payload = { 'hello' => 'world' }
    encrypted_text = encryptor1.dump(payload)
    expect(encryptor2.load(encrypted_text)).to eq(payload)
  end

  it 'does not modify the user access key when decrypting a payload encrypted with an old key' do
    old_encryptor = SessionEncryptor.new
    old_payload = old_encryptor.dump('asdf' => '1234')

    new_encryptor = SessionEncryptor.new
    new_payload = new_encryptor.dump('1234' => 'asdf')
    original_cek = new_encryptor.duped_user_access_key.cek

    expect(new_encryptor.load(old_payload)).to eq('asdf' => '1234')
    expect(new_encryptor.duped_user_access_key.cek).to eq(original_cek)

    expect(new_encryptor.load(new_payload)).to eq('1234' => 'asdf')
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
    end
  end
end
