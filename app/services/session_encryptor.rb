class SessionEncryptor
  MARSHAL_SIGNATURE ||= 'BAh'.freeze

  def self.build_user_access_key
    key = Figaro.env.session_encryption_key
    UserAccessKey.new(password: key, salt: key)
  end

  cattr_reader :user_access_key do
    build_user_access_key
  end

  def self.load(value)
    decrypted = encryptor.decrypt(value, user_access_key)

    if decrypted.start_with?(MARSHAL_SIGNATURE)
      Rails.logger.info 'Marshalled session found'
      # rubocop:disable Security/MarshalLoad
      Marshal.load(::Base64.decode64(decrypted)).tap do |decoded_value|
        dump(decoded_value)
      end
      # rubocop:enable Security/MarshalLoad
    else
      JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
    end
  end

  def self.dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain, user_access_key)
  end

  def self.encryptor
    Pii::PasswordEncryptor.new
  end
end
