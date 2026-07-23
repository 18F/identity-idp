require 'rails_helper'

RSpec.describe EncryptedDocStorage::LocalStorage do
  let(:img_path) { Rails.root.join('app', 'assets', 'images', 'logo.svg') }
  let(:image) { File.read(img_path) }
  let(:encrypted_image) do
    Encryption::AesCipherV2.new.encrypt(image, SecureRandom.bytes(32))
  end

  let(:name) { SecureRandom.uuid }
  let(:local_img_path) { Rails.root.join('tmp', 'encrypted_doc_storage', name) }

  let(:user_uuid) { SecureRandom.uuid }
  let(:attempts_path) do
    Rails.root.join('tmp', 'encrypted_attempt_events', 'attempt_events', user_uuid)
  end
  subject { EncryptedDocStorage::LocalStorage.new }

  describe '#write_image' do
    it 'writes the document to the disk' do
      subject.write_image(encrypted_image:, name:)

      f = File.new(local_img_path, 'rb')
      result = f.read
      f.close

      # cleanup
      File.delete(local_img_path)

      expect(result).to eq(encrypted_image)
    end
  end

  describe '#write_attempt_events' do
    it 'writes the attempt events to the disk' do
      encrypted_attempt_events = SecureRandom.bytes(32)

      subject.write_attempt_events(path: "attempt_events/#{user_uuid}", encrypted_attempt_events:)

      f = File.new(attempts_path, 'rb')
      result = f.read
      f.close

      # cleanup
      File.delete(attempts_path)

      expect(result).to eq(encrypted_attempt_events)
    end
  end

  describe '#retrieve' do
    let(:path) { 'attempt_events' }
    let(:encrypted_attempt_events) { 'abcd1245' }
    it 'retrieves the attempt events from the disk' do
      # Write the file first
      subject.write_attempt_events(path: "#{path}/#{user_uuid}", encrypted_attempt_events:)

      result = subject.retrieve_attempt_object(file_path: path, file_name: user_uuid)

      # cleanup
      File.delete(attempts_path)

      expect(result).to eq(encrypted_attempt_events)
    end
  end

  describe '#delete' do
    let(:name) { SecureRandom.uuid }
    let(:user_uuid) { 'user-uuid' }
    let(:encrypted_attempt_events) { 'abcd1245' }
    let(:path) { "attempt_events/#{user_uuid}" }

    before do
      allow(FileUtils).to receive(:rm_rf).and_call_original
    end

    it 'deletes the directory' do
      subject.write_attempt_events(path: "#{path}/#{name}", encrypted_attempt_events:)

      expect(subject.retrieve_attempt_object(file_path: path, file_name: name))
        .to eq(encrypted_attempt_events)

      subject.delete_user_attempt_data(user_uuid:)

      expect(FileUtils).to have_received(:rm_rf).with(attempts_path)
      expect(subject.retrieve_attempt_object(file_path: path, file_name: name)).to be nil
    end

    describe 'if there is no directory' do
      it 'does not attempt to delete' do
        subject.delete_user_attempt_data(user_uuid:)

        expect(FileUtils).to_not have_received(:rm_rf)
      end
    end
  end
end
