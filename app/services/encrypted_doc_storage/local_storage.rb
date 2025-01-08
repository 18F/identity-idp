# frozen_string_literal: true

module EncryptedDocStorage
  class LocalStorage
    def write_image(encrypted_image:, name:)
      FileUtils.mkdir_p(tmp_document_storage_dir)

      File.open(tmp_document_storage_dir.join(name), 'wb') do |f|
        f.write(encrypted_image)
      end
    end

    private

    def tmp_document_storage_dir
      Rails.root.join('tmp', 'encrypted_doc_storage')
    end
  end
end
