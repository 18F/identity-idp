module PrivateKeyFileHelper
  # Returns the private key in AppArtifacts.store.oidc_private_key if
  # Identity::Hostdata.in_datacenter? or if the private key file does
  # not exist; otherwise, the private key from the file is returned.
  def private_key_from_store_or(file_name:)
    file_name = force_tmp_private_key_file_name file_name: file_name

    if Rails.env.test? && !File.exist?(file_name)
      puts "WARNING: Private key file '#{file_name}' not found!" # rubocop:disable Rails/Output
    end

    if File.exist?(file_name)
      OpenSSL::PKey::RSA.new(File.read(file_name))
    else
      return AppArtifacts.store.oidc_private_key
    end
  end

  # Always ensure we're referencing files in the /tmp/ folder!
  def force_tmp_private_key_file_name(file_name:)
    "#{Rails.root}/tmp/#{File.basename(file_name)}"
  end
end

RSpec.configure do |config|
  config.include PrivateKeyFileHelper
end
