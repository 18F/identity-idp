module PwnedPasswords
  class LookupPassword
    PWNED_PASSWORD_FILE = Rails.root.join('pwned_passwords', 'pwned_passwords.txt')

    def self.call(password)
      BinarySearchSortedHashFile.new(PWNED_PASSWORD_FILE).call(password)
    end
  end
end
