require 'rails_helper'

RSpec.describe EncryptedDocStorage::LocalStorage do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:encrypted_image) do
    Encryption::AesCipherV2.new.encrypt(image, SecureRandom.bytes(32))
  end

  describe '#write_image' do
    it 'writes the document to the disk' do
      name = SecureRandom.uuid

      EncryptedDocStorage::LocalStorage.new.write_image(
        encrypted_image:,
        name:,
      )
      path = Rails.root.join('tmp', 'encrypted_doc_storage', name)

      f = File.new(path, 'rb')
      result = f.read
      f.close

      # cleanup
      File.delete(path)

      expect(result).to eq(encrypted_image)
    end
  end

  describe '#write_attempt_events' do
    it 'writes the attempt events to the disk' do
      path = SecureRandom.uuid
      encrypted_attempt_events = SecureRandom.bytes(32)

      EncryptedDocStorage::LocalStorage.new.write_attempt_events(
        path:,
        encrypted_attempt_events:,
      )
      full_path = Rails.root.join('tmp', 'encrypted_attempt_events', path)

      f = File.new(full_path, 'rb')
      result = f.read
      f.close

      # cleanup
      File.delete(full_path)

      expect(result).to eq(encrypted_attempt_events)
    end
  end

  describe '#retrieve' do
    let(:name) { SecureRandom.uuid }
    let(:path) { 'attempts' }
    let(:encrypted_attempt_events) { 'abcd1245' }
    it 'retrieves the attempt events from the disk' do
      # Write the file first
      EncryptedDocStorage::LocalStorage.new.write_attempt_events(
        path: path + '/' + name,
        encrypted_attempt_events:,
      )

      result = EncryptedDocStorage::LocalStorage.new.retrieve_attempt_object(
        file_path: path, file_name: name,
      )

      # cleanup
      File.delete(Rails.root.join('tmp', 'encrypted_attempt_events', path, name))

      expect(result).to eq(encrypted_attempt_events)
    end
  end
end
