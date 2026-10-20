require 'rails_helper'

RSpec.describe EncryptedDocStorage::DocReader do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:storage) { EncryptedDocStorage::RedisStorage.new }
  let(:writer) { EncryptedDocStorage::DocWriter.new(storage:) }

  subject { described_class.new(storage:) }

  describe '#initialize' do
    context 'when no storage is given' do
      subject { described_class.new }

      it 'reads from the Redis store the images are written to' do
        result = writer.write(image:)

        read_image = subject.read(name: result.name, encryption_key: result.encryption_key)
        storage.delete_image(name: result.name)

        expect(read_image).to eq(image)
      end
    end
  end

  describe '#read' do
    it 'decrypts an image previously written by DocWriter' do
      result = writer.write(image:)

      read_image = subject.read(name: result.name, encryption_key: result.encryption_key)
      storage.delete_image(name: result.name)

      expect(read_image).to eq(image)
    end

    it 'returns nil when the object is missing' do
      expect(subject.read(name: 'encrypted_images/missing', encryption_key: 'x')).to be_nil
    end

    it 'returns nil rather than raising when the key cannot decrypt the object' do
      result = writer.write(image:)
      wrong_key = Base64.strict_encode64(SecureRandom.bytes(32))

      read_image = subject.read(name: result.name, encryption_key: wrong_key)
      storage.delete_image(name: result.name)

      expect(read_image).to be_nil
    end

    it 'returns nil for a malformed (non-base64) key' do
      result = writer.write(image:)

      read_image = subject.read(name: result.name, encryption_key: 'not base64!!')
      storage.delete_image(name: result.name)

      expect(read_image).to be_nil
    end

    it 'returns nil for a blank key without touching the ciphertext' do
      result = writer.write(image:)

      read_image = subject.read(name: result.name, encryption_key: nil)
      storage.delete_image(name: result.name)

      expect(read_image).to be_nil
    end
  end
end
