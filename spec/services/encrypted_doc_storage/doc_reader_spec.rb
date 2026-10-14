require 'rails_helper'

RSpec.describe EncryptedDocStorage::DocReader do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }

  describe '#read' do
    it 'decrypts an image previously written by DocWriter' do
      writer = EncryptedDocStorage::DocWriter.new
      result = writer.write(image:)

      read_image = subject.read(name: result.name, encryption_key: result.encryption_key)

      File.delete(Rails.root.join('tmp', 'encrypted_doc_storage', result.name))

      expect(read_image).to eq(image)
    end

    it 'returns nil when the object is missing' do
      expect(subject.read(name: 'encrypted_images/missing', encryption_key: 'x')).to be_nil
    end

    it 'returns nil rather than raising when the key cannot decrypt the object' do
      writer = EncryptedDocStorage::DocWriter.new
      result = writer.write(image:)
      wrong_key = Base64.strict_encode64(SecureRandom.bytes(32))

      read_image = subject.read(name: result.name, encryption_key: wrong_key)
      File.delete(Rails.root.join('tmp', 'encrypted_doc_storage', result.name))

      expect(read_image).to be_nil
    end

    it 'returns nil for a malformed (non-base64) key' do
      writer = EncryptedDocStorage::DocWriter.new
      result = writer.write(image:)

      read_image = subject.read(name: result.name, encryption_key: 'not base64!!')
      File.delete(Rails.root.join('tmp', 'encrypted_doc_storage', result.name))

      expect(read_image).to be_nil
    end

    context 'when S3Storage is enabled' do
      subject { described_class.new(s3_enabled: true) }

      it 'reads from S3' do
        expect_any_instance_of(EncryptedDocStorage::S3Storage).to receive(:read_image)
          .with(name: 'encrypted_images/abc').and_return(nil)
        expect_any_instance_of(EncryptedDocStorage::LocalStorage).not_to receive(:read_image)

        subject.read(name: 'encrypted_images/abc', encryption_key: 'x')
      end
    end
  end
end
