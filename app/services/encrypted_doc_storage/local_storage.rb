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

    private

    def tmp_document_storage_dir
      Rails.root.join('tmp', 'encrypted_doc_storage')
    end
  end
end
