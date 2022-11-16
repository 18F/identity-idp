module EncryptedDocumentStorage
  class LocalStorage
    def write_document(encrypted_document:, reference:)
      FileUtils.mkdir_p(tmp_document_storage_dir)
      filepath = tmp_document_storage_dir.join(reference)
      File.write(filepath, encrypted_document)
    end

    def tmp_document_storage_dir
      Rails.root.join('tmp/encrypted_doc_storage')
    end
  end
end
