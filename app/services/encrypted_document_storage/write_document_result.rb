module EncryptedDocumentStorage
  WriteDocumentResult = Struct.new(
    :front_reference,
    :base_reference,
    :encryption_key,
    key_word_init: true,
  )
end
