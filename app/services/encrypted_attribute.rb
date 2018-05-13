class EncryptedAttribute
  extend Forwardable

  attr_reader :encrypted, :decrypted

  def self.new_from_decrypted(decrypted)
    encrypted = Encryption::Encryptors::AttributeEncryptor.new.encrypt(decrypted)
    new(encrypted, decrypted: decrypted)
  end

  def initialize(encrypted, decrypted: nil)
    self.encrypted = encrypted
    self.decrypted = decrypted.presence || encryptor.decrypt(encrypted)
  end

  def fingerprint
    Pii::Fingerprinter.fingerprint(decrypted)
  end

  def_delegators :encryptor, :stale?

  private

  attr_writer :encrypted, :decrypted

  def encryptor
    @encryptor ||= Encryption::Encryptors::AttributeEncryptor.new
  end
end
