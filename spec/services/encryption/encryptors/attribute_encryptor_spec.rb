require 'rails_helper'

describe Encryption::Encryptors::AttributeEncryptor do
  let(:plaintext) { 'some secret text' }
  let(:current_key) { '1' * 32 }
  let(:current_cost) { '400$8$1$' }
  let(:retired_key) { '2' * 32 }
  let(:retired_cost) { '2000$8$1$' }

  before do
    described_class.instance_variable_set(:@_scypt_hashes_by_key, nil)

    allow(Figaro.env).to receive(:attribute_encryption_key).and_return(current_key)
    allow(Figaro.env).to receive(:attribute_cost).and_return(current_cost)
    allow(Figaro.env).to receive(:attribute_encryption_key_queue).and_return(
      [{ key: retired_key, cost: retired_cost }].to_json
    )
  end

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to_not eq(plaintext)
    end

    it 'only computes an scrypt hash the first time a key is used' do
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      subject.encrypt(plaintext)

      expect(SCrypt::Engine).to_not receive(:hash_secret)

      subject.encrypt(plaintext)
    end
  end

  describe '#decrypt' do
    let(:ciphertext) do
      result = subject.encrypt(plaintext)
      described_class.instance_variable_set(:@_scypt_hashes_by_key, nil)
      result
    end

    before do
      # Memoize the ciphertext and purge the key pool so that encryption does not
      # affect expected call counts
      ciphertext
    end

    context 'with a ciphertext made with the current key' do
      it 'decrypts the ciphertext' do
        expect(subject.decrypt(ciphertext)).to eq(plaintext)
      end

      it 'only computes an scrypt hash the first time a keys is used' do
        expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

        subject.decrypt(ciphertext)

        expect(SCrypt::Engine).to_not receive(:hash_secret)

        subject.decrypt(ciphertext)
      end
    end

    context 'after rotating keys' do
      before do
        rotate_attribute_encryption_key
      end

      it 'tries to decrypt with successive keys until it is successful' do
        expect(Encryption::UserAccessKey).to receive(:new).twice.and_call_original

        expect(subject.decrypt(ciphertext)).to eq(plaintext)
      end
    end

    context 'with a ciphertext made with a key that does not exist' do
      before do
        rotate_attribute_encryption_key_with_invalid_queue
      end

      it 'raises and encryption error' do
        expect { subject.decrypt(ciphertext) }.to raise_error(
          Pii::EncryptionError, 'unable to decrypt attribute with any key'
        )
      end
    end
  end

  describe '#stale?' do
    it 'returns false if the current key last was used to decrypt something' do
      ciphertext = subject.encrypt(plaintext)
      subject.decrypt(ciphertext)

      expect(subject.stale?).to eq(false)
    end

    it 'returns true if an old key was last used to decrypt something' do
      ciphertext = subject.encrypt(plaintext)
      rotate_attribute_encryption_key
      subject.decrypt(ciphertext)

      expect(subject.stale?).to eq(true)
    end
  end

  describe '.load_or_init_user_access_key' do
    it 'does not return the same key object for the same salt and cost' do
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      key1 = described_class.load_or_init_user_access_key(key: current_key, cost: current_cost)
      key2 = described_class.load_or_init_user_access_key(key: current_key, cost: current_cost)

      expect(key1.as_scrypt_hash).to eq(key2.as_scrypt_hash)
      expect(key1).to_not eq(key2)
    end
  end
end
