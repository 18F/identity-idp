class FileEncryptor
  class EncryptionError < StandardError; end

  def initialize(path_to_public_gpg_key, recipient_email)
    @gpg_key_path = path_to_public_gpg_key
    @recipient_email = recipient_email
  end

  def encrypt(text, output_file)
    IO.pipe do |stdin_read_io, stdin_write_io|
      IO.pipe do |stderr_read_io, stderr_write_io|
        stdin_write_io.syswrite(text)
        stdin_write_io.close

        success = system(gpg_encrypt_command(output_file), in: stdin_read_io, err: stderr_write_io)
        stderr_write_io.close
        raise EncryptionError, "gpg error: #{stderr_read_io.read}" unless success
      end
    end
  end

  def decrypt(passphrase, input_file)
    IO.pipe do |stdout_read_io, stdout_write_io|
      system(
        gpg_decrypt_command(passphrase, input_file),
        out: stdout_write_io,
        err: '/dev/null'
      )
      stdout_write_io.close
      stdout_read_io.read
    end
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
         --pinentry-mode loopback \
         --status-fd \
         --with-colons \
          --no-tty \
         -e \
         -r #{Shellwords.shellescape(recipient_email)} \
         --output #{Shellwords.shellescape(outfile)}
    "
  end
  # rubocop:enable MethodLength

  def gpg_decrypt_command(passphrase, infile)
    password = Shellwords.shellescape(passphrase)
    "echo #{password} | PASSPHRASE=#{password} gpg --batch \
      --pinentry-mode loopback --command-fd 0 -d #{Shellwords.shellescape(infile)}"
  end
end
