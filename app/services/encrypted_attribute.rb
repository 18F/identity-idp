class EncryptedAttribute
  attr_accessor :user_access_key
  attr_reader :encrypted, :decrypted

  def self.new_user_access_key(cost: nil, key: nil)
    env = Figaro.env
    key ||= env.attribute_encryption_key
    cost ||= env.attribute_cost
    new_key = load_or_build_user_access_key(cost: cost, key: key).dup
    new_key.random_r = Pii::Cipher.random_key
    new_key
  end

  def self.new_from_decrypted(decrypted, user_access_key = new_user_access_key)
    encryptor = Pii::PasswordEncryptor.new
    encrypted = encryptor.encrypt(decrypted, user_access_key)
    new(encrypted, decrypted: decrypted, user_access_key: user_access_key)
  end

  def initialize(encrypted, decrypted: nil, cost: nil, user_access_key: nil)
    self.encrypted = encrypted
    self.user_access_key = user_access_key
    self.decrypted = decrypted.presence || decrypt(cost)
  end

  def fingerprint
    Pii::Fingerprinter.fingerprint(decrypted)
  end

  def stale?
    user_access_key.salt != current_salt
  end

  private

  attr_writer :encrypted, :decrypted

  private_class_method def self.load_or_build_user_access_key(cost:, key:)
    @_uaks_by_key ||= {}
    uak_lookup = "#{key}:#{cost}"
    @_uaks_by_key[uak_lookup] ||= UserAccessKey.new(password: key, salt: key, cost: cost)
  end

  def current_salt
    user_access_key.cost + OpenSSL::Digest::SHA256.hexdigest(Figaro.env.attribute_encryption_key)
  end

  def decrypt(cost)
    encryptor = Pii::PasswordEncryptor.new
    decrypted = try_decrypt_with_uak(encryptor) if user_access_key.present?
    return decrypted if decrypted
    try_decrypt_with_all_keys(encryptor, cost)
  end

  def try_decrypt(encryptor, key, cost)
    self.user_access_key = self.class.new_user_access_key(cost: cost, key: key)
    encryptor.decrypt(encrypted, user_access_key)
  rescue Pii::EncryptionError => _err
    nil
  end

  def try_decrypt_with_all_keys(encryptor, cost)
    encryption_keys.each do |key|
      decrypted = try_decrypt(encryptor, key, cost) or next
      return decrypted
    end

    raise Pii::EncryptionError, 'unable to decrypt attribute with any key'
  end

  def try_decrypt_with_uak(encryptor)
    encryptor.decrypt(encrypted, user_access_key)
  rescue Pii::EncryptionError => _err
    nil
  end

  def encryption_keys
    [Figaro.env.attribute_encryption_key] + old_keys
  end

  def old_keys
    KeyRotator::Utils.old_keys(:attribute_encryption_key_queue)
  end
end
