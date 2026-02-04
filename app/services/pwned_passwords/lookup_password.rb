# frozen_string_literal: true

module PwnedPasswords
  class LookupPassword
    PWNED_PASSWORD_FILE = Rails.root.join(IdentityConfig.store.pwned_passwords_file_path).freeze

    def self.call(password)
      response = BinarySearchSortedHashFile.new(PWNED_PASSWORD_FILE).call(password)
      # JRA: we should not add event here -- it neesd to be only on login
      puts 'Looooooooooooook'
      puts response
      response
    end
  end
end
