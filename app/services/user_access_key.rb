# UserAccessKey outputs various key hashing related to NIST encryption.
#
# Generate and store a 128-bit salt S.
# Z1, Z2 = scrypt(S, password)   # split 256-bit output into two halves
# Generate random R.
# D = KMS_GCM_Encrypt(key=server_secret, plaintext=R) xor Z1
# E = hash( Z2 + R )
# F = hash(E)
# Store F (User.encrypted_password) and D (User.encryption_key) in db

class UserAccessKey
  include ::NewRelic::Agent::MethodTracer

  attr_accessor :cost, :encrypted_d, :salt, :z1, :z2, :random_r

  def initialize(password:, salt:, cost: nil)
    self.cost = cost
    self.cost ||= Figaro.env.scrypt_cost
    build(password, salt)
    self.unlocked = false
    self.made = false
  end

  def as_scrypt_hash
    "#{salt}$#{z1}#{z2}"
  end

  def hash_e
    OpenSSL::Digest::SHA256.hexdigest(z2 + random_r)
  end

  alias cek hash_e

  def hash_f
    OpenSSL::Digest::SHA256.hexdigest(hash_e)
  end

  alias encrypted_password hash_f

  def xor(ciphertext)
    ciphertext_len = ciphertext.length
    raise 'ciphertext must be at least 256 bits long' if ciphertext_len < 32
    ciphertext_unpacked = ciphertext.unpack('C*')

    # z1 and ciphertext must be the same length.
    z1_unpacked = z1_with_padding(ciphertext_len).unpack('C*')

    z1_unpacked.zip(ciphertext_unpacked).map { |z1_byte, ct_byte| z1_byte ^ ct_byte }.pack('C*')
  end

  def store_encrypted_key(encrypted_key)
    self.made = true
    self.encrypted_d = xor(encrypted_key)
  end

  def encryption_key
    Base64.strict_encode64(encrypted_d)
  end

  def unlock(random_key)
    raise Pii::EncryptionError, 'Cannot unlock with nil random_key' if random_key.blank?
    self.unlocked = true
    self.random_r = random_key
    hash_e
  end

  def unlocked?
    unlocked
  end

  def made?
    made
  end

  private

  attr_accessor :made, :unlocked

  def z1_with_padding(length)
    z1.dup.rjust(length, '0')
  end

  def build(password, pw_salt)
    self.salt = cost + OpenSSL::Digest::SHA256.hexdigest(pw_salt)
    scrypted = SCrypt::Engine.hash_secret password, salt, 32
    self.z1, self.z2 = build_segments(scrypted)
    self.random_r = Pii::Cipher.random_key
  end
  add_method_tracer :build, 'Custom/UserAccessKey/build'

  def build_segments(scrypted)
    hashed = SCrypt::Password.new(scrypted).digest
    segment_one = hashed.slice!(0...32)
    [segment_one, hashed]
  end
end
