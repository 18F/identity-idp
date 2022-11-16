require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::DocumentWriter do
  describe '#encrypt_and_write_document' do
    context 'in production' do
      it 'encrypts the document and writes it to S3'
    end

    context 'outside production' do
      it 'encrypts the document and writes it to the disk'
    end
  end
end
