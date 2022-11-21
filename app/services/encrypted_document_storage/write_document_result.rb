module EncryptedDocumentStorage
  WriteDocumentResult = Struct.new(
    :front_uuid,
    :back_uuid,
    :front_encryption_key,
    :back_encryption_key,
    keyword_init: true,
  )
end
