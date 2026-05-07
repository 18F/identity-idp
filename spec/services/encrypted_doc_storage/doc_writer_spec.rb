require 'rails_helper'

RSpec.describe EncryptedDocStorage::DocWriter do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:issuer) { 'issuer' }
  subject { EncryptedDocStorage::DocWriter.new }
  describe '#write' do
    it 'encrypts the document and writes it to storage' do
      result = subject.write(issuer:, image:)

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

    context 'when two images are written with the same writer object' do
      it 'each image has a different key' do
        result = subject.write(issuer:, image:)
        result1 = subject.write(issuer:, image:)

        expect(result.name).not_to eq(result1.name)
        expect(result.encryption_key).not_to eq(result1.encryption_key)
        expect(result.name).to start_with(issuer)
        expect(result1.name).to start_with(issuer)
      end
    end

    it 'uses LocalStorage by default' do
      expect_any_instance_of(EncryptedDocStorage::LocalStorage).to receive(:write_image).once
      expect_any_instance_of(EncryptedDocStorage::S3Storage).to_not receive(:write_image)

      subject.write(issuer:, image:)
    end

    context 'when S3Storage is initalized' do
      subject do
        EncryptedDocStorage::DocWriter.new(s3_enabled: true)
      end

      it 'uses S3' do
        expect_any_instance_of(EncryptedDocStorage::S3Storage).to receive(:write_image).once
        expect_any_instance_of(EncryptedDocStorage::LocalStorage).not_to receive(:write_image)

        result = subject.write(issuer:, image:)
        expect(result.name).to start_with(issuer)
      end
    end

    context 'when an image is not passed in' do
      context 'when the image value is nil' do
        it 'returns a blank Result object' do
          result = subject.write(issuer:, image: nil)

          expect(result.name).to be nil
          expect(result.encryption_key).to be nil
        end
      end

      context 'when the image value is an empty string' do
        it 'returns a blank Result object' do
          result = subject.write(issuer:, image: '')

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

  describe '#write_encrypted_attempt_events' do
    let(:file_path) { 'file_path' }
    let(:encrypted_attempt_events) { { events: 'encrypted_attempt_events' }.to_json }
    let(:uuid) { 'test-uuid' }
    let(:path) { "#{file_path}/#{uuid}" }
    before do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
    end

    it 'writes the encrypted attempt events to storage' do
      expect_any_instance_of(EncryptedDocStorage::LocalStorage).to receive(
        :write_attempt_events,
      ).with(
        path:,
        encrypted_attempt_events:,
      )

      result = subject.write_encrypted_attempt_events(file_path:, encrypted_attempt_events:)
      expect(result.name).to eq(uuid)
    end

    context 'when S3Storage is initalized' do
      subject do
        EncryptedDocStorage::DocWriter.new(s3_enabled: true)
      end

      it 'uses S3' do
        expect_any_instance_of(EncryptedDocStorage::S3Storage).to receive(
          :write_attempt_events,
        ).with(
          path:,
          encrypted_attempt_events:,
        )
        expect_any_instance_of(EncryptedDocStorage::LocalStorage).not_to receive(
          :write_attempt_events,
        )

        result = subject.write_encrypted_attempt_events(file_path:, encrypted_attempt_events:)
        expect(result.name).to eq(uuid)
      end
    end
  end

  def file_path(uuid)
    Rails.root.join('tmp', 'encrypted_doc_storage', uuid)
  end
end
