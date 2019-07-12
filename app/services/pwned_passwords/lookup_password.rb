module PwnedPasswords
  class LookupPassword
    def self.call(password)
      BinarySearchSortedHashFile.new(Figaro.env.pwned_password_file).call(password)
    end
  end
end
