require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::LocalStorage do
  describe '#write_document' do
    it 'writes the document to the disk' do
      encrypted_document = "hello, i'm the encrypted document."
      reference = SecureRandom.uuid

      EncryptedDocumentStorage::LocalStorage.new.write_document(
        encrypted_document: encrypted_document,
        reference: reference,
      )

      result = File.read(
        Rails.root.join('tmp', 'encrypted_doc_storage', reference),
      )
      expect(result).to eq(encrypted_document)
    end
  end
end
