require 'rails_helper'
RSpec.describe EncryptedDocStorage::AttemptDataHandler do
  subject { EncryptedDocStorage::AttemptDataHandler.new }
  let(:file_path) { 'file/path' }
  let(:file_name) { 'file_name' }

  describe '#retrieve_user_proofing_events' do
    let(:local_storage) { double('LocalStorage') }
    before do
      allow(EncryptedDocStorage::LocalStorage).to receive(:new).and_return(local_storage)
    end

    it 'defaults to retrieving events from local storage' do
      expect(local_storage).to receive(:retrieve_attempt_object).with(file_path:, file_name:)
      subject.retrieve_user_proofing_events(file_path:, file_name:)
    end

    context 'when S3 is enabled' do
      subject { EncryptedDocStorage::AttemptDataHandler.new(s3_enabled: true) }
      let(:s3_storage) { double('S3Storage') }

      before do
        allow(EncryptedDocStorage::S3Storage).to receive(:new).and_return(s3_storage)
      end

      it 'retrieves events from S3 storage' do
        expect(s3_storage).to receive(:retrieve_attempt_object).with(file_path:, file_name:)
        subject.retrieve_user_proofing_events(file_path:, file_name:)
      end
    end
  end

  describe '#delete_all_user_attempt_data' do
    let(:local_storage) { double('LocalStorage') }
    let(:user_uuid) { SecureRandom.uuid }
    before do
      allow(EncryptedDocStorage::LocalStorage).to receive(:new).and_return(local_storage)
    end

    it 'defaults to retrieving events from local storage' do
      expect(local_storage).to receive(:delete_user_attempt_data).with(user_uuid:)
      subject.delete_all_user_attempt_data(user_uuid:)
    end

    context 'when S3 is enabled' do
      subject { EncryptedDocStorage::AttemptDataHandler.new(s3_enabled: true) }
      let(:s3_storage) { double('S3Storage') }

      before do
        allow(EncryptedDocStorage::S3Storage).to receive(:new).and_return(s3_storage)
      end

      it 'retrieves events from S3 storage' do
        expect(s3_storage).to receive(:delete_user_attempt_data).with(user_uuid:)
        subject.delete_all_user_attempt_data(user_uuid:)
      end
    end
  end
end
