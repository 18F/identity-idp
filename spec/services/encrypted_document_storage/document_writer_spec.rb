require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::DocumentWriter do
  describe '#encrypt_and_write_document' do
    it 'encrypts the document and writes it to storage' do
      front_image = 'hello, i am the front image'
      back_image = 'hello, i am the back image'

      result = EncryptedDocumentStorage::DocumentWriter.new.encrypt_and_write_document(
        front_image: front_image,
        back_image: back_image,
      )

      front_file_path = Rails.root.join('tmp', 'encrypted_doc_storage', result.front_reference)
      back_file_path = Rails.root.join('tmp', 'encrypted_doc_storage', result.back_reference)
      key = Base64.strict_decode64(result.encryption_key)

      aes_cipher = Encryption::AesCipher.new

      written_front_image = aes_cipher.decrypt(
        File.read(front_file_path),
        key,
      )
      written_back_image = aes_cipher.decrypt(
        File.read(back_file_path),
        key,
      )

      expect(written_front_image).to eq(front_image)
      expect(written_back_image).to eq(back_image)
    end
  end

  describe '#storage' do
    subject { EncryptedDocumentStorage::DocumentWriter.new }

    context 'in production' do
      it 'is uses S3' do
        allow(Rails.env).to receive(:production?).and_return(true)

        expect(subject.storage).to be_a(EncryptedDocumentStorage::S3Storage)
      end
    end

    context 'outside production' do
      it 'it uses the disk' do
        allow(Rails.env).to receive(:production?).and_return(false)

        expect(subject.storage).to be_a(EncryptedDocumentStorage::LocalStorage)
      end
    end
  end
end
