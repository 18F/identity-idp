module EncryptedDocumentStorage
  WriteDocumentResult = Struct.new(
    :front_reference,
    :back_reference,
    :encryption_key,
    keyword_init: true,
  )
end
