require 'rails_helper'

RSpec.describe EncryptedDocStorage::DocWriter do
  describe '#write' do
    let(:front_image) { 'front_image' }
    let(:back_image) { 'back_image' }

    subject do
      EncryptedDocStorage::DocWriter.new
    end

    it 'encrypts the document and writes it to storage' do
      result = subject.write(
        front_image:,
        back_image:,
      )

      key = Base64.strict_decode64(result.encryption_key)
      aes_cipher = Encryption::AesCipher.new

      written_front_image = aes_cipher.decrypt(
        File.read(file_path(result.front_uuid)),
        key,
      )
      written_back_image = aes_cipher.decrypt(
        File.read(file_path(result.back_uuid)),
        key,
      )

      expect(written_front_image).to eq(front_image)
      expect(written_back_image).to eq(back_image)
    end

    it 'uses LocalStorage by default' do
      expect_any_instance_of(EncryptedDocStorage::LocalStorage).to receive(:write_image).twice
      expect_any_instance_of(EncryptedDocStorage::S3Storage).to_not receive(:write_image)

      subject.write(
        front_image:,
        back_image:,
      )
    end

    context 'when S3Storage is passed in' do
      it 'uses S3' do
        expect_any_instance_of(EncryptedDocStorage::S3Storage).to receive(:write_image).twice
        expect_any_instance_of(EncryptedDocStorage::LocalStorage).not_to receive(:write_image)

        subject.write(
          front_image:,
          back_image:,
          data_store: EncryptedDocStorage::S3Storage,
        )
      end
    end

    def file_path(uuid)
      Rails.root.join('tmp', 'encrypted_doc_storage', uuid)
    end
  end
end
