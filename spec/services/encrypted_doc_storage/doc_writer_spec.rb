require 'rails_helper'

RSpec.describe EncryptedDocStorage::DocWriter do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  subject { EncryptedDocStorage::DocWriter.new }
  describe '#write' do
    it 'encrypts the document and writes it to storage' do
      result = subject.write(image:)

      key = Base64.strict_decode64(result.encryption_key)
      aes_cipher = Encryption::AesCipherV2.new

      written_image = aes_cipher.decrypt(
        File.read(file_path(result.name)),
        key,
      )

      # cleanup
      File.delete(file_path(result.name))

      expect(written_image).to eq(image)
    end

    it 'uses LocalStorage by default' do
      expect_any_instance_of(EncryptedDocStorage::LocalStorage).to receive(:write_image).once
      expect_any_instance_of(EncryptedDocStorage::S3Storage).to_not receive(:write_image)

      subject.write(image:)
    end

    context 'when S3Storage is initalized' do
      subject do
        EncryptedDocStorage::DocWriter.new(s3_enabled: true)
      end

      it 'uses S3' do
        expect_any_instance_of(EncryptedDocStorage::S3Storage).to receive(:write_image).once
        expect_any_instance_of(EncryptedDocStorage::LocalStorage).not_to receive(:write_image)

        subject.write(image:)
      end
    end

    context 'when an image is not passed in' do
      context 'when the image value is nil' do
        it 'returns a blank Result object' do
          result = subject.write(image: nil)

          expect(result.name).to be nil
          expect(result.encryption_key).to be nil
        end
      end

      context 'when the image value is an empty string' do
        it 'returns a blank Result object' do
          result = subject.write(image: '')

          expect(result.name).to be nil
          expect(result.encryption_key).to be nil
        end
      end
    end
  end

  describe '#write_with_data' do
    let(:key) {  SecureRandom.bytes(32) }
    let(:name) { 'name' }
    let(:aes_cipher) { Encryption::AesCipherV2.new }
    let(:data) do
      {
        document_front_image_file_id: name,
        document_front_image_encryption_key: Base64.strict_encode64(key),
      }
    end

    before do
      expect(Encryption::AesCipherV2).to receive(:new).and_return(aes_cipher)
    end

    it 'writes the image with provided data' do
      expect(aes_cipher).to receive(:encrypt).with(image, key).and_return 'encrypted_image'
      expect_any_instance_of(EncryptedDocStorage::LocalStorage).to receive(:write_image).with(
        encrypted_image: 'encrypted_image',
        name:,
      )

      subject.write_with_data(image:, name:, encryption_key: key)
    end
  end

  def file_path(uuid)
    Rails.root.join('tmp', 'encrypted_doc_storage', uuid)
  end
end
