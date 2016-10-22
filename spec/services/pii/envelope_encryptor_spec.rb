require 'rails_helper'

describe Pii::EnvelopeEncryptor do
  let(:password) { 'sekrit' }
  let(:key_maker) { Pii::KeyMaker.new }
  let(:plaintext) { 'four score and seven years ago' }
  let(:cipher) { Pii::Cipher.new }
  subject { Pii::EnvelopeEncryptor.new(key_maker) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext)

      expect(subject.decrypt(encrypted)).to eq plaintext
    end
  end

  describe 'Digital Envelope Encryption Model (DEEM)' do
    context '#encrypt' do
      it 'encrypts the AES random CEK and stores it with payload' do
        encrypted = subject.encrypt(plaintext)
        encrypted_cek = split_payload(encrypted).first
        decrypted_cek = cipher.decrypt(encrypted_cek, key_maker.fetch_server_cek)

        expect(decrypted_cek).to be_a String
      end

      it 'enfolds plaintext, signature and encrypted CEK' do
        signature = subject.sign(plaintext)
        encrypted = subject.encrypt(plaintext)
        encrypted_cek, encrypted_payload = split_payload(encrypted)
        decrypted_cek = cipher.decrypt(encrypted_cek, key_maker.fetch_server_cek)
        decrypted_payload = cipher.decrypt(encrypted_payload, decrypted_cek)
        original_plaintext, original_signature = split_payload(decrypted_payload)

        expect(original_plaintext).to eq plaintext
        expect(original_signature).to eq signature
      end
    end
  end

  def split_payload(payload)
    payload.split(described_class::DELIMITER).map { |segment| Base64.strict_decode64(segment) }
  end
end
