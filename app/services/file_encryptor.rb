class FileEncryptor
  def initialize(path_to_public_gpg_key, recipient_email)
    @gpg_key_path = path_to_public_gpg_key
    @recipient_email = recipient_email
  end

  def encrypt(text, output_file)
    open("| #{gpg_encrypt_command(output_file)}", 'wb') do |filehandle|
      filehandle.syswrite(text)
    end
  end

  def decrypt(passphrase, input_file)
    `#{gpg_decrypt_command(passphrase, input_file)}`
  end

  private

  attr_reader :gpg_key_path, :recipient_email

  # rubocop:disable MethodLength
  def gpg_encrypt_command(outfile)
    "gpg --no-default-keyring \
         --keyring #{Shellwords.shellescape(gpg_key_path)} \
         --trust-model always \
         --cipher-algo aes256 \
         --digest-algo sha256 \
         --batch \
         --yes \
         -e \
         -r #{Shellwords.shellescape(recipient_email)} \
         --output #{Shellwords.shellescape(outfile)}
    "
  end
  # rubocop:enable MethodLength

  def gpg_decrypt_command(passphrase, infile)
    "gpg --batch \
         --passphrase #{Shellwords.shellescape(passphrase)} \
         -d #{Shellwords.shellescape(infile)}
    "
  end
end
