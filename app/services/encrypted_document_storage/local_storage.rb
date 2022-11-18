module EncryptedDocumentStorage
  class LocalStorage
    def write_image(encrypted_image:, name:)
      FileUtils.mkdir_p(tmp_document_storage_dir)
      filepath = tmp_document_storage_dir.join(name)
      File.write(filepath, encrypted_image)
    end

    def tmp_document_storage_dir
      Rails.root.join('tmp', 'encrypted_doc_storage')
    end
  end
end
