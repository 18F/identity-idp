require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::LocalStorage do
  describe '#write_image' do
    it 'writes the document to the disk' do
      encrypted_image = "hello, i'm the encrypted document."
      reference = SecureRandom.uuid

      EncryptedDocumentStorage::LocalStorage.new.write_image(
        encrypted_image: encrypted_image,
        reference: reference,
      )

      result = File.read(
        Rails.root.join('tmp', 'encrypted_doc_storage', reference),
      )
      expect(result).to eq(encrypted_image)
    end
  end
end
