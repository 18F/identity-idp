require 'rails_helper'

describe Encryption::Encryptors::AttributeEncryptor do
  let(:plaintext) { 'some secret text' }
  let(:current_key) { '1' * 32 }
  let(:current_cost) { '400$8$1$' }
  let(:retired_key) { '2' * 32 }
  let(:retired_cost) { '2000$8$1$' }

  before do
    allow(Figaro.env).to receive(:attribute_encryption_key).and_return(current_key)
    allow(Figaro.env).to receive(:attribute_cost).and_return(current_cost)
    allow(Figaro.env).to receive(:attribute_encryption_key_queue).and_return(
      [{ key: retired_key, cost: retired_cost }].to_json,
    )
  end

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to_not eq(plaintext)
    end
  end

  describe '#decrypt' do
    context 'with new new non kms based encryption' do
      let(:ciphertext) do
        subject.encrypt(plaintext)
      end

      before do
        # Memoize the ciphertext so that encryption does not affect expected
        # call counts
        ciphertext
      end

      context 'with a ciphertext made with the current key' do
        it 'decrypts the ciphertext' do
          expect(subject.decrypt(ciphertext)).to eq(plaintext)
        end
      end

      context 'after rotating keys' do
        before do
          rotate_attribute_encryption_key
        end

        it 'tries to decrypt with successive keys until it is successful' do
          expect(subject.decrypt(ciphertext)).to eq(plaintext)
        end
      end

      context 'with a ciphertext made with a key that does not exist' do
        before do
          rotate_attribute_encryption_key_with_invalid_queue
        end

        it 'raises and encryption error' do
          expect { subject.decrypt(ciphertext) }.to \
            raise_error(Encryption::EncryptionError, 'unable to decrypt attribute with any key')
        end
      end
    end
  end

  describe '#stale?' do
    it 'returns false if the current key last was used to decrypt something' do
      ciphertext = subject.encrypt(plaintext)
      subject.decrypt(ciphertext)

      expect(subject.stale?).to eq(false)
    end

    it 'returns true if old key used to decrypt and we turn on new encryption' do
      ciphertext = subject.encrypt(plaintext)
      rotate_attribute_encryption_key
      subject.decrypt(ciphertext)

      expect(subject.stale?).to eq(true)
    end
  end
end
