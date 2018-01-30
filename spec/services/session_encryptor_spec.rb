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

  it 'encrypts successive payloads with the same encryption key' do
    first_encryptor = SessionEncryptor.new
    first_payload = first_encryptor.dump('first' => 'payload 1')

    second_encryptor = SessionEncryptor.new
    second_payload = second_encryptor.dump('second' => 'payload 2')

    expect(second_encryptor.load(first_payload)).to eq('first' => 'payload 1')

    third_payload = second_encryptor.dump('third' => 'payload 3')

    expect(third_payload.split('.').first).to eq(second_payload.split('.').first)
    expect(second_encryptor.load(second_payload)).to eq('second' => 'payload 2')
    expect(second_encryptor.load(third_payload)).to eq('third' => 'payload 3')
  end

  it 'performs successive operations without remaking user access keys' do
    encrypted_key_maker = EncryptedKeyMaker.new
    allow(EncryptedKeyMaker).to receive(:new).and_return(encrypted_key_maker).at_least(1).times

    expect(encrypted_key_maker).to receive(:make).and_call_original.exactly(2).times
    expect(encrypted_key_maker).to receive(:unlock).and_call_original.exactly(2).times

    encryptor1 = SessionEncryptor.new
    encryptor2 = SessionEncryptor.new

    encryptor1.load(encryptor1.dump('asdf' => '1234'))
    encryptor2.load(encryptor2.dump('asdf' => '1234'))
    encryptor1.load(encryptor1.dump('qwerty' => '1234'))
    encryptor2.load(encryptor2.dump('qwerty' => '1234'))
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.new.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
    end
  end
end
