require 'rails_helper'

describe Pii::RsaEncryptor do
  let(:password) { 'sekrit' }
  let(:key_maker) { Pii::KeyMaker.new }
  let(:private_rsa_key) { Pii::KeyMaker.rsa_key(key_maker.generate_rsa(password), password) }
  let(:plaintext) { 'four score and seven years ago' }
  subject { Pii::RsaEncryptor.new(key_maker) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext, private_rsa_key)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext, private_rsa_key)

      expect(subject.decrypt(encrypted, private_rsa_key)).to eq plaintext
    end

    it 'requires same RSA key used for encrypt_with_rsa' do
      encrypted = subject.encrypt(plaintext, private_rsa_key)
      new_key_pem = key_maker.generate_rsa('password')
      new_key = Pii::KeyMaker.rsa_key(new_key_pem, 'password')

      expect do
        subject.decrypt(encrypted, new_key)
      end.to raise_error OpenSSL::PKey::RSAError
    end
  end

  describe 'Digital Envelope Encryption Model (DEEM)' do
    context '#encrypt' do
      it 'encrypts the AES random CEK with public key' do
        expect(private_rsa_key).to receive(:public_encrypt).once.and_call_original

        encrypted = subject.encrypt(plaintext, private_rsa_key)
        encrypted_cek = split_payload(encrypted).first
        decrypted_cek = private_decrypt(private_rsa_key, encrypted_cek)

        expect(decrypted_cek).to be_a String
      end

      it 'enfolds plaintext, signature and encrypted CEK' do
        signature = subject.sign(plaintext)
        encrypted = subject.encrypt(plaintext, private_rsa_key)
        encrypted_cek, encrypted_payload = split_payload(encrypted)
        decrypted_cek = private_decrypt(private_rsa_key, encrypted_cek)
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
