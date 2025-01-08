require 'rails_helper'

RSpec.describe EncryptedDocStorage::S3Storage do
  subject { EncryptedDocStorage::S3Storage.new }
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:encrypted_image) do
    Encryption::AesCipherV2.new.encrypt(image, SecureRandom.bytes(32))
  end

  describe '#write_image' do
    let(:stubbed_s3_client) { Aws::S3::Client.new(stub_responses: true) }

    before do
      allow(subject).to receive(:s3_client).and_return(stubbed_s3_client)
      allow(stubbed_s3_client).to receive(:put_object)
    end

    it 'writes the document to S3' do
      name = '123abc'

      subject.write_image(encrypted_image:, name:)

      expect(stubbed_s3_client).to have_received(:put_object).with(
        bucket: IdentityConfig.store.encrypted_document_storage_s3_bucket,
        key: name,
        body: encrypted_image,
      )
    end
  end
end
