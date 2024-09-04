# frozen_string_literal: true

# UserAccessKey outputs various key hashing related to NIST encryption.
#
# Generate and store a 128-bit salt S.
# Z1, Z2 = scrypt(S, password)   # split 256-bit output into two halves
# Generate random R.
# D = KMS_GCM_Encrypt(key=server_secret, plaintext=R) xor Z1
# E = hash( Z2 + R )
# F = hash(E)
# Store F (User.encrypted_password) and D (User.encryption_key) in db
#
module Encryption
  class UserAccessKey
    include ::NewRelic::Agent::MethodTracer

    attr_reader :cost, :salt, :z1, :z2, :random_r, :masked_ciphertext, :cek

    # rubocop:disable Layout/LineLength
    def initialize(password: nil, salt: nil, cost: nil, scrypt_hash: nil, user_uuid: nil, log_context: nil)
      cost ||= IdentityConfig.store.scrypt_cost
      scrypt_password = if scrypt_hash.present?
                          SCrypt::Password.new(scrypt_hash)
                        else
                          build_scrypt_password(password, salt, cost)
                        end
      self.cost = scrypt_password.cost
      self.salt = scrypt_password.salt
      self.z1, self.z2 = split_scrypt_digest(scrypt_password.digest)
      @user_uuid = user_uuid
      @log_context = log_context
    end
    # rubocop:enable Layout/LineLength

    def as_scrypt_hash
      "#{cost}#{salt}$#{z1}#{z2}"
    end

    def build
      self.random_r = SecureRandom.random_bytes(32)
      encrypted_random_r = kms_client.encrypt(random_r)
      z1_padded = z1.dup.rjust(encrypted_random_r.length, '0')
      self.masked_ciphertext = xor(z1_padded, encrypted_random_r)
      self.cek = OpenSSL::Digest::SHA256.hexdigest(z2 + random_r)
      self
    end

    def unlock(encryption_key_arg)
      self.masked_ciphertext = Base64.strict_decode64(encryption_key_arg)
      z1_padded = z1.dup.rjust(masked_ciphertext.length, '0')
      encrypted_random_r = xor(z1_padded, masked_ciphertext)
      self.random_r = kms_client.decrypt(
        encrypted_random_r,
        log_context: {
          context: @log_context,
          user_uuid: @user_uuid,
        },
      )
      self.cek = OpenSSL::Digest::SHA256.hexdigest(z2 + random_r)
      self
    end

    def unlocked?
      cek.present?
    end
    alias_method :built?, :unlocked?

    def encryption_key
      Base64.strict_encode64(masked_ciphertext)
    end

    def encrypted_password
      OpenSSL::Digest::SHA256.hexdigest(cek)
    end

    private

    attr_writer :cost, :salt, :z1, :z2, :random_r, :masked_ciphertext, :cek

    def build_scrypt_password(password, salt, cost)
      scrypt_salt = cost + transform_password_salt_to_scrypt_salt(salt)
      scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
      SCrypt::Password.new(scrypted)
    end

    def transform_password_salt_to_scrypt_salt(salt)
      # Legacy passwords had 20 byte salts, so we took a SHA256 digest to get
      # to 32 bytes. While passwords exist with 20 byte salts, we will need this
      # line, otherwise the passwords are effectively expired.
      #
      # Also note that the salt arg will have a length of 64 chars since it is
      # a hex digest of 32 random bytes
      return OpenSSL::Digest::SHA256.hexdigest(salt) if salt.length != 64
      salt
    end

    def kms_client
      ContextlessKmsClient.new
    end

    def split_scrypt_digest(digest)
      [
        digest.slice(0...32),
        digest.slice(32...64),
      ]
    end

    def xor(left, right)
      left_unpacked = left.unpack('C*')
      right_unpacked = right.unpack('C*')
      left_unpacked.zip(right_unpacked).map do |left_byte, right_byte|
        left_byte ^ right_byte
      end.pack('C*')
    end

    add_method_tracer :initialize, "Custom/#{name}/build"
  end
end
