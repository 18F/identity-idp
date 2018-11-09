class RecoveryCode < ApplicationRecord
  #self.ignored_columns = %w(encrypted_code)

  belongs_to :user

  #include EncryptableAttribute
  #encrypted_attribute(name: :code)

  #include RecoveryCodeEncryptedAttributeOverrides
end
