require 'rails_helper'

RSpec.describe EncryptedDocStorage::S3Storage do
  subject { EncryptedDocStorage::S3Storage.new }
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:encrypted_image) do
    Encryption::AesCipherV2.new.encrypt(image, SecureRandom.bytes(32))
  end
  let(:stubbed_s3_client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    allow(subject).to receive(:s3_client).and_return(stubbed_s3_client)
  end
  describe '#write_image' do
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

  describe '#write_attempt_events' do
    before do
      allow(subject).to receive(:s3_client).and_return(stubbed_s3_client)
      allow(stubbed_s3_client).to receive(:put_object)
    end

    it 'writes the attempt events to S3' do
      path = 'attempt_events/123abc'
      encrypted_attempt_events = SecureRandom.bytes(32)

      subject.write_attempt_events(path:, encrypted_attempt_events:)

      expect(stubbed_s3_client).to have_received(:put_object).with(
        bucket: IdentityConfig.store.encrypted_document_storage_s3_bucket,
        key: path,
        body: encrypted_attempt_events,
      )
    end
  end
  describe '#retrieve_attempt_object' do
    let(:file_name) { SecureRandom.uuid }
    let(:file_path) { '123abc' }
    let(:encrypted_data) { SecureRandom.bytes(32) }

    before do
      allow(subject).to receive(:s3_client).and_return(stubbed_s3_client)

      response = double(body: StringIO.new(encrypted_data))
      allow(stubbed_s3_client).to receive(:get_object).and_return(response)
    end

    it 'retrieves the attempt events from S3' do
      result = subject.retrieve_attempt_object(file_path:, file_name:)

      expect(stubbed_s3_client).to have_received(:get_object).with(
        bucket: IdentityConfig.store.encrypted_document_storage_s3_bucket,
        key: "attempt_events/#{file_path}/#{file_name}",
      )
      expect(result).to eq(encrypted_data)
    end
  end

  describe '#delete_user_attempt_data' do
    let(:user_uuid) { SecureRandom.uuid }
    let(:file_path) { "attempt_events/#{user_uuid}" }
    it 'deletes the directory' do
      expect(stubbed_s3_client).to receive(:delete_object).with(
        bucket: IdentityConfig.store.encrypted_document_storage_s3_bucket,
        key: file_path,
      )

      subject.delete_user_attempt_data(user_uuid:)
    end
  end
end
