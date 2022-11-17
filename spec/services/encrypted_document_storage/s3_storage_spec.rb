require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::S3Storage do
  describe '#write_image' do
    it 'writes the document to S3' do
      encrypted_image = 'hello, i am the encrypted document.'
      name = '123abc'

      storage = EncryptedDocumentStorage::S3Storage.new

      stubbed_s3_client = Aws::S3::Client.new(stub_responses: true)
      allow(storage).to receive(:s3_client).and_return(stubbed_s3_client)

      expect(stubbed_s3_client).to receive(:put_object).and_call_original
      stubbed_s3_client.stub_responses(
        :put_object,
        ->(context) {
          params = context.params
          expect(params[:bucket]).to eq(IdentityConfig.store.encrypted_document_storage_s3_bucket)
          expect(params[:key]).to eq(name)
          expect(params[:body]).to eq(encrypted_image)
        },
      )

      storage.write_image(encrypted_image: encrypted_image, name: name)
    end
  end
end
