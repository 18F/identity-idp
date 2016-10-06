require 'rails_helper'

describe Pii::Encryptor do
  let(:password) { 'sekrit' }
  let(:key_maker) { Pii::KeyMaker.new }
  let(:plaintext) { 'four score and seven years ago' }
  subject { Pii::Encryptor.new(key_maker) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext, password)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext, password)

      expect(subject.decrypt(encrypted, password)).to eq plaintext
    end

    it 'rejects tampered text' do
      encrypted = subject.encrypt(plaintext, password)
      key, payload = encrypted.split(described_class::DELIMITER)
      payload = Base64.strict_encode64(Base64.strict_decode64(payload) + '123')
      reencrypted = [key, payload].join(described_class::DELIMITER)

      expect { subject.decrypt(reencrypted, password) }.to raise_error OpenSSL::Cipher::CipherError
    end

    it 'requires same password used for encrypt' do
      encrypted = subject.encrypt(plaintext, password)

      expect do
        subject.decrypt(encrypted, 'different password')
      end.to raise_error OpenSSL::PKey::RSAError
    end
  end

  describe '#encrypt_with_key' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt_with_key(plaintext, key_maker.server_key)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt_with_key' do
    it 'returns original text' do
      encrypted = subject.encrypt_with_key(plaintext, key_maker.server_key)

      expect(subject.decrypt_with_key(encrypted, key_maker.server_key)).to eq plaintext
    end

    it 'requires same RSA key used for encrypt_with_key' do
      encrypted = subject.encrypt_with_key(plaintext, key_maker.server_key)
      new_key_pem = key_maker.generate('password')
      new_key = Pii::KeyMaker.rsa_key(new_key_pem, 'password')

      expect do
        subject.decrypt_with_key(encrypted, new_key)
      end.to raise_error OpenSSL::PKey::RSAError
    end
  end

  describe 'Digital Envelope Encryption Model (DEEM)' do
    context '#encrypt' do
      it 'applies DEEM twice' do
        allow(subject).to receive(:encrypt_with_key).and_call_original

        expect(subject).to receive(:encrypt_with_key).
                           with(instance_of(String), instance_of(OpenSSL::PKey::RSA)).
                           twice

        subject.encrypt(plaintext, password)
      end

      it 'encrypts plaintext with user password-protected key' do
        allow(key_maker).to receive(:generate).with(password).and_call_original

        expect(key_maker).to receive(:generate).with(password).once

        subject.encrypt(plaintext, password)
      end

      it 'enfolds user key within first DEEM layer' do
        encrypted = subject.encrypt(plaintext, password)
        user_encrypted_bundle = subject.decrypt_with_key(encrypted, key_maker.server_key)
        user_encrypted_pem = split_payload(user_encrypted_bundle).first
        user_key = Pii::KeyMaker.rsa_key(user_encrypted_pem, password)

        expect(user_key).to be_a OpenSSL::PKey::RSA
      end
    end

    context '#encrypt_with_key' do
      it 'encrypts the AES random CEK with public key' do
        expect(key_maker.server_key).to receive(:public_encrypt).once.and_call_original

        encrypted = subject.encrypt_with_key(plaintext, key_maker.server_key)
        encrypted_cek = split_payload(encrypted).first
        decrypted_cek = private_decrypt(key_maker.server_key, encrypted_cek)

        expect(decrypted_cek).to be_a String
      end

      it 'enfolds plaintext, signature and encrypted CEK' do
        signature = subject.sign(plaintext)
        encrypted = subject.encrypt_with_key(plaintext, key_maker.server_key)
        encrypted_cek, encrypted_payload = split_payload(encrypted)
        decrypted_cek = private_decrypt(key_maker.server_key, encrypted_cek)
        decrypted_payload = decipher(encrypted_payload, decrypted_cek)
        original_plaintext, original_signature = split_payload(decrypted_payload)

        expect(original_plaintext).to eq plaintext
        expect(original_signature).to eq signature
      end
    end
  end

  def split_payload(payload)
    payload.split(described_class::DELIMITER).map { |segment| Base64.strict_decode64(segment) }
  end

  def private_decrypt(key, ciphertext)
    key.private_decrypt(ciphertext, described_class::PADDING)
  end

  def decipher(ciphertext, cek)
    cipher = OpenSSL::Cipher.new 'AES-256-CBC'
    cipher.decrypt
    iv_len = cipher.iv_len
    cipher.padding = 0
    cipher.iv = ciphertext[0...iv_len]
    cipher.key = cek
    deciphered = cipher.update(ciphertext[iv_len..-1]) << cipher.final
    padding_size = deciphered.last.unpack('c').first
    deciphered[0...-padding_size]
  end
end
