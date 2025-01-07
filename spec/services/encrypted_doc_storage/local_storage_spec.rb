require 'rails_helper'

RSpec.describe EncryptedDocStorage::LocalStorage do
  describe '#write_image' do
    it 'writes the document to the disk' do
      encrypted_image = 'encrypted document.'
      name = SecureRandom.uuid

      EncryptedDocStorage::LocalStorage.new.write_image(
        encrypted_image:,
        name:,
      )

      result = File.read(
        Rails.root.join('tmp', 'encrypted_doc_storage', name),
      )
      expect(result).to eq(encrypted_image)
    end
  end
end
