# frozen_string_literal: true

module EncryptedDocStorage
  class LocalStorage
    def write_image(encrypted_image:, name:)
      full_path = tmp_document_storage_dir.join(name)
      FileUtils.mkdir_p(full_path.dirname)

      File.open(full_path, 'wb') do |f|
        f.write(encrypted_image)
      end
    end

    # @param [String] file_path "#{user_uuid}/#{profile.id}/#{file.uuid}"
    # @param [String] encrypted_attempt_events a bundle of events that have been encrypted
    def write_attempt_events(path:, encrypted_attempt_events:)
      full_path = tmp_attempt_events_dir.join(path)
      FileUtils.mkdir_p(full_path.dirname)

      File.open(full_path, 'wb') do |f|
        f.write(encrypted_attempt_events)
      end
    end

    # @param [String] file_path "#{user_uuid}/#{profile.id}/#{file.uuid}"
    # @param [String] file_name profile.encrypted_attempts_file_reference
    def retrieve_attempt_object(file_path:, file_name:)
      full_path = tmp_attempt_events_dir.join(file_path, file_name)

      File.read(full_path) if File.exist?(full_path)
    end

    def delete_user_attempt_data(user_uuid:)
      full_path = tmp_attempt_events_dir.join(user_uuid)

      FileUtils.rm_rf(full_path) if Dir.exist?(full_path)
    end

    private

    def tmp_document_storage_dir
      Rails.root.join('tmp', 'encrypted_doc_storage')
    end

    def tmp_attempt_events_dir
      Rails.root.join('tmp', 'attempt_events')
    end
  end
end
