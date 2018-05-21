require 'rails_helper'

describe Encryption::Encryptors::SessionEncryptor do
  let(:plaintext) { '{ "foo": "bar" }' }

  before do
    described_class.instance_variable_set(:@user_access_key_scrypt_hash, nil)
  end

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to_not eq(plaintext)
    end

    it 'only computes an scrypt hash on the first encryption' do
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      subject.encrypt(plaintext)

      expect(SCrypt::Engine).to_not receive(:hash_secret)

      subject.encrypt(plaintext)
    end
  end

  describe '#decrypt' do
    let(:ciphertext) do
      result = subject.encrypt(plaintext)
      described_class.instance_variable_set(:@user_access_key_scrypt_hash, nil)
      result
    end

    before do
      # Memoize the ciphertext and purge memoized key so that encryption does not
      # affect expected call counts
      ciphertext
    end

    it 'returns a decrypted ciphertext' do
      expect(subject.decrypt(ciphertext)).to eq(plaintext)
    end

    it 'only computes and scrypt hash on the first decryption' do
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      subject.decrypt(ciphertext)

      expect(SCrypt::Engine).to_not receive(:hash_secret)

      subject.decrypt(ciphertext)
    end
  end

  describe '.load_or_init_user_access_key' do
    it 'does not return the same key object for the same salt and cost' do
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      key1 = described_class.load_or_init_user_access_key
      key2 = described_class.load_or_init_user_access_key

      expect(key1.as_scrypt_hash).to eq(key2.as_scrypt_hash)
      expect(key1).to_not eq(key2)
    end
  end

  it 'makes a roundtrip across multiple encryptors' do
    encryptor1 = described_class.new
    encryptor2 = described_class.new

    # Memoize user access key scrypt hash
    encryptor1.decrypt(encryptor1.encrypt('asdf'))
    encryptor2.decrypt(encryptor2.encrypt('1234'))

    encrypted_text = encryptor1.encrypt(plaintext)
    expect(encryptor2.decrypt(encrypted_text)).to eq(plaintext)
  end
end
