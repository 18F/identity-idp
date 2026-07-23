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
  let(:profile_id) { '3' }
  let(:attempts_path) { Rails.root.join('tmp', 'attempt_events', user_uuid) }
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
    let(:file_path) { "#{user_uuid}/#{profile_id}/#{name}" }

    it 'writes the attempt events to the disk' do
      encrypted_attempt_events = SecureRandom.bytes(32)

      subject.write_attempt_events(path: file_path, encrypted_attempt_events:)

      f = File.new(attempts_path.join(profile_id, name), 'rb')
      result = f.read
      f.close

      # cleanup
      FileUtils.rm_rf(attempts_path)

      expect(result).to eq(encrypted_attempt_events)
    end
  end

  describe '#retrieve_attempt_object' do
    let(:encrypted_attempt_events) { 'abcd1245' }
    let(:file_path) { "#{user_uuid}/#{profile_id}" }
    it 'retrieves the attempt events from the disk' do
      # Write the file first
      subject.write_attempt_events(
        path: "#{file_path}/#{name}",
        encrypted_attempt_events:,
      )

      result = subject.retrieve_attempt_object(file_path:, file_name: name)

      # cleanup
      FileUtils.rm_rf(attempts_path)

      expect(result).to eq(encrypted_attempt_events)
    end
  end

  describe '#delete' do
    let(:encrypted_attempt_events) { 'abcd1245' }
    let(:file_path) { "#{user_uuid}/#{profile_id}" }

    before do
      allow(FileUtils).to receive(:rm_rf).and_call_original
    end

    it 'deletes the directory' do
      subject.write_attempt_events(path: "#{file_path}/#{name}", encrypted_attempt_events:)

      expect(subject.retrieve_attempt_object(file_path:, file_name: name))
        .to eq(encrypted_attempt_events)

      subject.delete_user_attempt_data(user_uuid:)

      expect(FileUtils).to have_received(:rm_rf).with(attempts_path)
      expect(subject.retrieve_attempt_object(file_path:, file_name: name)).to be nil
    end

    describe 'if there is no directory' do
      it 'does not attempt to delete' do
        subject.delete_user_attempt_data(user_uuid:)

        expect(FileUtils).to_not have_received(:rm_rf)
      end
    end
  end
end
