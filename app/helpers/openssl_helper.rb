module OpensslHelper
  def random_key_iv(size: 128, mode: :GCM)
    cipher = OpenSSL::Cipher::AES.new(size, mode)
    cipher.encrypt
    {
      key: cipher.random_key,
      iv: cipher.random_iv,
    }
  end

  def random_aes_key(size: 128, mode: :GCM)
    cipher = OpenSSL::Cipher::AES.new(size, mode)
    cipher.encrypt
    cipher.random_key
  end

  def random_aes_iv(size: 128, mode: :GCM)
    cipher = OpenSSL::Cipher::AES.new(size, mode)
    cipher.encrypt
    cipher.random_iv
  end

  def encrypt(plain:, key: nil, iv: nil, auth_data: '', size: 128, mode: :GCM)
    # cipher = aes_cipher(size: size, mode: mode)
    cipher = OpenSSL::Cipher::AES.new(size, mode)
    cipher.encrypt

    if key.nil?
      key = cipher.random_key
    else
      cipher.key = key
    end

    if iv.nil?
      iv = cipher.random_iv
    else
      cipher.iv = iv
    end

    cipher.auth_data = auth_data

    encrypted = cipher.update(plain) + cipher.final
    tag = cipher.auth_tag

    {
      plain: plain,
      encrypted: encrypted,
      key: key,
      iv: iv,
      auth_data: auth_data,
      tag: tag,
      size: 128,
      mode: :GCM,
    }
  end

  def decrypt(encrypted:, key:, iv:, tag:, auth_data: '', size: 128, mode: :GCM)
    # decipher = aes_decipher(key: key, iv: iv, size: size, mode: mode)
    decipher = OpenSSL::Cipher::AES.new(size, mode)
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv
    decipher.auth_tag = tag
    decipher.auth_data = auth_data
    decrypted = decipher.update(encrypted) + decipher.final
    {
      encrypted: encrypted,
      decrypted: decrypted,
      key: @aes_key,
      iv: @aes_iv,
      auth_data: auth_data,
      tag: @aes_tag,
      size: 128,
      mode: :GCM,
    }
  end

  def test_round_trip(**args)
    encrypt_params = %i[plain key iv auth_data size mode]
    decrypt_params = %i[encrypted key iv auth_data tag size mode]

    encrypted_data = encrypt(args.slice(*encrypt_params))
    puts "\nencrypted_data:"
    pp encrypted_data

    decrypted_data = decrypt(encrypted_data.slice(*decrypt_params))
    puts "\ndecrypted_data:"
    pp decrypted_data

    if decrypted_data[:decrypted] == args[:plain]
      puts "\n*** it works! ***\n"
    else
      puts "\nsomething went wrong"
      puts "        plain: #{args[:plain]}"
      puts "    encrypted: #{encrypted_data[:encrypted]}"
      puts "    decrypted: #{decrypted_data[:decrypted]}"
    end
  end
end
