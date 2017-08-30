class UspsConfirmation < ApplicationRecord
  def decrypted_entry
    UspsConfirmationEntry.new_from_encrypted(entry)
  end
end
