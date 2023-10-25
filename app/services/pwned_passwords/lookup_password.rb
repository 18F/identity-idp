# frozen_string_literal: true

module PwnedPasswords
  class LookupPassword
    PWNED_PASSWORD_FILE = Rails.root.join(IdentityConfig.store.pwned_passwords_file_path).freeze

    def self.call(password)
      BinarySearchSortedHashFile.new(PWNED_PASSWORD_FILE).call(password)
    end
  end
end
