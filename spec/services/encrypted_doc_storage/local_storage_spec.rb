require 'rails_helper'

RSpec.describe EncryptedDocStorage::LocalStorage do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg')}
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
end
