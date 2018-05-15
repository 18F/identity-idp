require 'rails_helper'

describe SessionEncryptor do
  describe '#load' do
    it 'decrypts encrypted session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(SessionEncryptor.new.load(session)).to eq('foo' => 'bar')
    end
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
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
end
