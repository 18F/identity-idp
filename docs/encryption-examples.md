# Login.gov encryption examples:

Here are some simple functions that distill down some of the encryption process that Login.gov uses.

These examples are designed to run in the IDP's application environment and depend on having a few things available to them:

- _An AWS KMS Client_. This is a instance of the [KMS Client](http://docs.aws.amazon.com/sdkforruby/api/Aws/KMS/Client.html) provided by AWS's Ruby SDK. This provides us with a hardware security module. This object is named `aws_kms_client` in the examples. An example for mocking the KMS Client is also provided.
- _SCrypt_. SCrypt key derivation is provided by the [scrypt gem](https://github.com/pbhogan/scrypt).
- _Devise_. [Devise](https://github.com/plataformatec/devise) is a ruby gem that provides the authentication framework.
- _ActiveSupport::SecurityUtils_. ActiveSupport is part of Rails's API and its [SecurityUtils Module](http://api.rubyonrails.org/classes/ActiveSupport/SecurityUtils.html) provides a method for secure comparison.
- _SecureRandom_. [SecureRandom](https://ruby-doc.org/stdlib-2.4.0/libdoc/securerandom/rdoc/SecureRandom.html) is a part of the ruby standard library used to generate secure random numbers.
- _OpenSSL_. [OpenSSL](http://ruby-doc.org/stdlib-2.4.0/libdoc/openssl/rdoc/OpenSSL.html) is part of the ruby standard library and is used for general purpose cryptography.

## Creating a user access key

The user access key creation process creates a value named `CEK` (Content Encryption Key) which is used to encrypt the user's PII. Additionally, a hash of `CEK` is used as the user's password digest to verify the user's password during authentication.

In order to create a user access key, the following are necessary:

- `user`: An instance of the User model
- `password`: The user's plaintext password

The user access key creation process writes a number of attributes to the database with the user model. Those attributes are:

- `password_salt`: A random string used as password salt
- `password_cost`: The SCrypt cost used when generating a SCrypt digest from the password
- `encrypted_password`: A `SHA256` digest of `CEK` that is used to verify a user's password during authentication
- `encryption_key`: A value generated during the encryption process that is used to unlock the user access key to decrypt PII or verify the user's password. Also referred to as `D` or `MaskedCiphertext`

Here is a function that creates a user access key:

```ruby
## Pseudocode
#
# salt = random(20 bytes)
# cost = scrypt_calibrate(0.5)
#
# S = scrypt(password, password_salt, cost)
#
# Z1 = S[0:32]
# Z2 = S[32:64]
#
# R = random(32 bytes)
# R' = HSM_encrypt(R)
#
# D = R' XOR pad_right(Z1, '0', 32 bytes)
#
# CEK = SHA256(Z2 + R)
# digest = SHA256(CEK)
# encryption_key = encode(D)
#
# save_user(user, digest, salt, cost, encryption_key)
#
def create_user_access_key(user, password)
  # Generate a password salt
  user.password_salt = Devise.friendly_token[0, 20]

  # Create a scrypt digest using the passowrd and salt
  scrypt_cost = SCrypt::Engine.calibrate(max_time: 0.5)
  scrypt_salt = scrypt_cost + OpenSSL::Digest::SHA256.hexdigest(password_salt)
  scrypted = SCrypt::Engine.hash_secret(password, scrypt_salt, 32)

  # Using the scrypt digest, assign Z1 and Z2. Then generate R
  scrypt_digest = SCrypt::Password.new(scrypted).digest
  z1 = scrypt_digest.slice(0...32)
  z2 = scrypt_digest.slice(32...64)

  # Generate a random value R
  assigned_secret_r = SecureRandom.random_bytes(32)

  # Using KMS hardware encryption to create R'
  encrypted_assigned_secret_r = aws_kms_client.encrypt(
    key_id: 'my-kms-key',
    plaintext: assigned_secret_r
  ).ciphertext_blob
  encrypted_assigned_secret_r = 'KMSx' + encrypted_assigned_secret_r

  # Z1 needs to be padded to match the length of R'
  z1_padded = z1.dup.rjust(encrypted_assigned_secret_r.length, '0')

  # XOR encypted_R and padded Z1 to create D
  z1_unpacked = z1_padded.unpack('C*')
  encrypted_assigned_secret_r_unpacked = encrypted_assigned_secret_r.unpack('C*')
  masked_ciphertext_d = z1_unpacked.zip(encrypted_assigned_secret_r_unpacked).map do |z1_byte, r_byte|
    z1_byte ^ r_byte
  end.pack('C*')

  # Concatenate Z1 and D to create CEK(E)
  cek = OpenSSL::Digest::SHA256.hexdigest(z2 + assigned_secret_r)

  # Use hash of CEK to create PasswordHash
  encrypted_password = OpenSSL::Digest::SHA256.hexdigest(cek)

  # Store Cost, D, and PasswordHash with the user record
  user.password_cost = scrypt_cost
  user.encryption_key = Base64.strict_encode64(masked_ciphertext_d)
  user.encrypted_password = encrypted_password
  user.save!

  # Return CEK
  cek
end
```

## Unlocking a user access key

Unlocking an access key refers to using a user's password to find the value of `CEK` for a previously created access key. Unlocking a user access key requires a `user` and a `password`, the same things required to create an access key.

Unlike creating an access key, unlocking a user access key does not modify the user record. It does, however, read several values from the user record:

- `password_salt`: A random string used as password salt
- `password_cost`: The SCrypt cost used when generating a SCrypt digest from the password
- `encryption_key`: A value generated during the encryption process. It is the Base64 encoded value of `D`

Here is a function that unlocks a user access key:

```ruby
## Pseudocode
#
# S = scrypt(password, password_salt, cost)
#
# Z1 = S[0:32]
# Z2 = S[32:64]
#
# D = decode(encryption_key)
#
# R' = D XOR pad_right(Z1, '0', 32 bytes)
# R = HSM_decrypt(R')
#
# CEK = SHA256(Z2 + R)
#
def unlock_user_access_key(user, password, encryption_key = nil)
  # Encryption key is stored with encrypted PII and the user record. It
  # is passed as an arg while decrypting PII.
  encryption_key ||= user.encryption_key

  # Create a scrypt digest using the password, salt, and cost
  password_salt = user.password_salt
  scrypt_cost = user.password_cost
  scrypt_salt = scrypt_cost + OpenSSL::Digest::SHA256.hexdigest(password_salt)
  scrypted = SCrypt::Engine.hash_secret(password, scrypt_salt, 32)

  # Using the scrypt digest, assign Z1 and Z2
  scrypt_digest = SCrypt::Password.new(scrypted).digest
  z1 = scrypt_digest.slice(0...32)
  z2 = scrypt_digest.slice(32...64)

  # Decode encryption_key to get D.
  masked_ciphertext_d = Base64.strict_decode64(encryption_key)

  # Z1 needs to be padded to match the length of D
  z1_padded = z1.dup.rjust(masked_ciphertext_d.length, '0')

  # XOR Z1 and D to determine R'
  z1_unpacked = z1_padded.unpack('C*')
  masked_ciphertext_d_unpacked = masked_ciphertext_d.unpack('C*')
  encrypted_assigned_secret_r = z1_unpacked.zip(masked_ciphertext_d_unpacked).map do |z1_byte, d_byte|
    z1_byte ^ d_byte
  end.pack('C*')

  # Use KMS to decrypt R' to determine R
  encrypted_assigned_secret_r = encrypted_assigned_secret_r.gsub('KMSx', '')
  assigned_secret_r = aws_kms_client.decrypt(
    ciphertext_blob: encrypted_assigned_secret_r.plaintext
  )

  # Use Z2 and R to create CEK
  cek = OpenSSL::Digest::SHA256.hexdigest(z2 + assigned_secret_r)

  # Return CEK
  cek
end
```

## Encrypting PII

PII is symetrically encrypted using AES256 in GCM mode. The key is the user's `CEK` which is created during user access key creation and derived by unlocking the user access key.

The PII is fingerprinted using HMAC before it is encrypted, and the fingerprint is encrypted along with the PII.

The user's encryption key used to derive `CEK` is stored as part of the encrypted PII blob. When the user changes their password, they will create a new encryption key, and their PII will need to be re-encrypted and stored with the new encryption key.

The following are necessary to encrypt PII:


- `password`: The user's password
- `user`: A User model object
- `user.profile`: A Profile model object. This model is related the user and is where the user's encrypted PII is stored.
- `HMAC_FINGERPRINT_KEY`: An application secret used to create HMAC fingerprints
- `pii`: A JSON encoded string of a user's PII.
- `unlock_user_access_key`: A function that calculates the value of CEK for a user given their password

Here is a function that encrypts PII:

```ruby
## Pseudocode
#
# CEK = unlock_user_access_key(user, password)
#
# fingerprint = HMAC(pii)
# C = encode(pii) + '.' + encode(pii_fingerprint)
#
# C' = AES256_encrypt(cek, finerprinted_pii)
#
# save_encrypted_pii(user, C')
#
def encrypt_pii(user, password, pii)
  # Use the user's password to derive cek
  cek = unlock_user_access_key(user, password)

  # Create a fingerprint of the PII. Base64 encode it and concat with encoded
  # PII.
  pii_fingerprint = OpenSSL::HMAC.hexdigest('SHA256', HMAC_FINGERPRINT_KEY, pii)
  fingerprinted_pii = [
    Base64.strict_encode64(pii),
    Base64.strict_encode64(pii_fingerprint)
  ].join('.')

  # Use the cek to encrypt the fingerprinted pii to make C'
  cipher = OpenSSL::Cipher.new 'aes-256-gcm'
  cipher.encrypt
  cipher.key = cek
  iv = cipher.random_iv
  cipher.auth_data = 'PII'
  ciphertext = cipher.update(fingerprinted_pii) + cipher.final
  encrypted_c = {
    iv: Base64.strict_encode64(iv),
    ciphertext: Base64.strict_encode64(ciphertext),
    tag: Base64.strict_encode64(cipher.auth_tag)
  }.to_json

  # Store C' alongside the encryption key as encrypted_pii
  user.profile.encrypted_pii = [
    # Encoded first by UserAccessKey, then again by Pii::PasswordEncryptor
    Base64.strict_encode64(user.encryption_key),
    Base64.strict_encode64(encrypted_c)
  ].join('.')
end
```

## Decrypting PII

PII is decrypted using AES256 in GCM mode. The key is the user's `CEK` which is created during user access key creation and derived by unlocking the user access key.

The PII is encrypted with a fingerprint that is used to verify the integrity of the decrypted data after decryption.

The following are necessary to decrypt PII:


- `password`: The user's password
- `user`: A User model object
- `user.profile`: A Profile model object that saves with an attribute for the encrypted PII blob
- `HMAC_FINGERPRINT_KEY`: An application secret used to create HMAC fingerprints
- `encrypted_pii`: The user's encryption key and encrypted fingerprinted PII joined by a `.`
- `unlock_user_access_key`: A function that calculates the value of CEK for a user given their password

Here is a function that decrypt's a user's PII:

```ruby
## Pseudocode
#
# CEK = unlock_user_access_key(user, password)
#
# C = AES256_decrypt(cek, C')
#
# pii, fingerprint = split(C, '.')
#
# if HMAC(pii) != pii {
#   raise EncryptionError
# }
#
def decrypt_pii(user, password, encrypted_pii)
  # The encrypted PII blob has 2 values joined by a `.`:
  # - The encryption key is encode(D) is the Base64 encoded value of D
  #   generated during the user access key generation.
  # - C' is a JSON encoded string with the IV, tag, and ciphertext from
  #   the PII encryption process
  encryption_key = Base64.strict_decode64(encrypted_pii.split('.').first)
  encrypted_c = Base64.strict_decode64(encrypted_pii.split('.').second)

  # Use D and the user's password to find CEK
  cek = unlock_user_access_key(user, password, encryption_key)

  # Unpacked C'
  unpacked_encrypted_c = JSON.parse(encrypted_c, symbolize_names: true)

  # Use the cek and C' to decrypt the fingerprinted PII
  cipher = OpenSSL::Cipher.new 'aes-256-gcm'
  cipher.decrypt
  cipher.key = cek
  cipher.iv = Base64.strict_decode64(unpacked_encrypted_c[:iv])
  cipher.auth_tag = Base64.strict_decode64(unpacked_encrypted_c[:tag])
  cipher.auth_data = 'PII'
  ciphertext = Base64.strict_decode64(unpacked_encrypted_c[:ciphertext])
  fingerprinted_pii = cipher.update(ciphertext) + cipher.final

  # Extract the PII and PII fingerprint from fingerprinted PII
  pii = Base64.strict_decode64(fingerprinted_pii.split('.').first)
  pii_fingerprint = Base64.strict_decode64(fingerprinted_pii.split('.').second)

  # Create a HMAC fingerprint of the PII and verify that our fingerprint
  # matches
  expected_pii_fingerprint = OpenSSL::HMAC.hexdigest(
    'SHA256',
    HMAC_FINGERPRINT_KEY,
    pii
  )
  raise EncryptionError if pii_fingerprint != expected_pii_fingerprint

  # Return the decrypted PII
  pii
end
```

## Verifying a user's password

When a new user access key is created, the hashed value of `CEK` is stored on the user model as `encrypted_password`. This value is used during authentication to verify that a user is providing the correct password. To verify a user's password, a user access key must be unlocked with the candidate password. The hashed `CEK` generated by unlocking the user access key is compared against the value of `encrypted_password` that was stored during user access key creation.

Here is a function for verifying a user's password:

```ruby
## Pseudocode
#
# CEK = unlock_user_access_key(user, password)
# digest = SHA256(CEK)
#
# if digest == user.password_digest {
#   return true
# } else {
#   return false
# }
#
def verify_password(user, password)
  # Use the entered password to derive CEK
  cek = unlock_user_access_key(user, password)

  # Use a hash of CEK to create PasswordHash
  password_digest = OpenSSL::Digest::SHA256.hexdigest(cek)

  # Compare the password digest with the user's encrypted password
  Devise.secure_compare(user.encrypted_password, password_digest)
end
```

## Mocking the HSM in dev

AWS KMS is used to encrypt the random value `R` that is generated during user access key creation. Since an HSM may not be available in development, AES256 in GCM mode with a secret known as `PASSWORD_PEPPER` is used as a stand in.

Here is a mock that can be used to mimic the HSM in dev:

```ruby
class HsmMock
  PASSWORD_PEPPER = ENV['PASSWORD_PEPPER']
  HMAC_FINGERPRINT_KEY = ENV['HMAC_FINGERPRINT_KEY']

  def initialize(*); end

  def encrypt(key_id: nil, plaintext: nil)
    raise if plaintext == nil

    cipher = OpenSSL::Cipher.new  'aes-256-gcm'
    cipher.encrypt
    cipher.key = PASSWORD_PEPPER
    iv = cipher.random_iv
    cipher.auth_data = 'PII'
    ciphertext = fingerprint_plaintext(plaintext) + cipher.final
    tag = cipher.final
    Base64.strict_encode64(
      {
        iv: Base64.strict_encode64(iv),
        ciphertext: Base64.strict_encode64(ciphertext),
        tag: Base64.strict_encode64(tag)
      }.to_json
    )
  end

  def decrypt(ciphertext_blob:)
    unpacked_ciphertex = JSON.parse(
      Base64.strict_decode64(ciphertext_blob),
      symbolize_names: true
    )

    cipher = OpenSSL::Cipher.new 'aes-256-gcm'
    cipher.decrypt
    cipher.key = PASSWORD_PEPPER
    cipher.iv = Base64.strict_decode64(unpacked_ciphertex[:iv])
    cipher.auth_tag = Base64.strict_decode64(unpacked_ciphertex[:tag])
    cipher.auth_data = 'PII'
    ciphertext = Base64.strict_decode64(unpacked_encrypted_c[:ciphertext])
    fingerprinted_plaintext = cipher.update(ciphertext) + cipher.final

    plaintext, fingerprint = fingerprinted_plaintext.split('.')
    verify_plaintext_fingerprint(plaintext, fingerprint)
    plaintext
  end

  def fingerprint_plaintext(plaintext)
    [
      Base64.strict_encode64(plaintext),
      Base64.strict_encode64(
        OpenSSL::HMAC.hexdigest('SHA256', HMAC_FINGERPRINT_KEY, plaintext)
      )
    ].join('.')
  end

  def verify_plaintext_fingerprint(plaintext, fingerprint)
    plaintext_fingerprint = OpenSSL::HMAC.hexdigest(
      'SHA256',
      HMAC_FINGERPRINT_KEY,
      plaintext
    )

    raise EncryptionError unless ActiveSupport::SecurityUtils.secure_compare(
      plaintext_fingerprint,
      fingerprint
    )
  end
end
```
