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
  attr_accessor :encrypted_d, :salt, :z1, :z2, :random_r

  # IMPORTANT! changing COST will invalidate existing password hashes.
  # You can generate a cost value with:
  #  SCrypt::Engine.calibrate(max_time: n)
  # where 'n' is e.g. 0.01 or 0.5 (as used here).
  SCRYPT_COST_MAX_TIME_0_DOT_01 = '800$8$1$'.freeze
  SCRYPT_COST_MAX_TIME_0_DOT_5  = '4000$8$4$'.freeze

  COST = Rails.env.test? ? SCRYPT_COST_MAX_TIME_0_DOT_01 : SCRYPT_COST_MAX_TIME_0_DOT_5

  def initialize(password, salt)
    factors = build(password, salt)
    self.salt = factors[:salt]
    self.z1 = factors[:z_one]
    self.z2 = factors[:z_two]
    self.random_r = factors[:random_r]
    @unlocked = false
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
    self.encrypted_d = xor(encrypted_key)
  end

  def encryption_key
    Base64.strict_encode64(encrypted_d)
  end

  def unlock(random_key)
    @unlocked = true
    self.random_r = random_key
    hash_e
  end

  def unlocked?
    @unlocked
  end

  private

  def z1_with_padding(len)
    cur_len = z1.length
    str = z1.dup
    while cur_len < len
      str = '0' + str
      cur_len += 1
    end
    str
  end

  def build(password, salt)
    scrypt_salt = COST + OpenSSL::Digest::SHA256.hexdigest(salt)
    scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
    segment_one, segment_two = build_segments(scrypted)
    random_r = Pii::Cipher.random_key
    { salt: scrypt_salt, z_one: segment_one, z_two: segment_two, random_r: random_r }
  end

  def build_segments(scrypted)
    hashed = SCrypt::Password.new(scrypted).digest
    segment_one = hashed.slice!(0...32)
    [segment_one, hashed]
  end
end
