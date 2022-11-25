module EncryptedDocumentStorage
  WriteDocumentResult = Struct.new(
    :front_filename,
    :back_filename,
    :encryption_key,
    keyword_init: true,
  )
end
