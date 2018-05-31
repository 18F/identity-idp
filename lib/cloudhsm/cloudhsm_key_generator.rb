require 'greenletters'
require 'io/console'

# Can be run standalone (without idp or rails) or through the rake task cloudhsm
# generates saml_<timestamp>.key, saml_<timestamp>.crt,
# and saml_<timestamp>.txt (a transcript of the cloudhsm interaction)
# the program interactively asks for username, password, and openssl.conf location

class CloudhsmKeyGenerator
  KEY_MGMT_UTIL = '/opt/cloudhsm/bin/key_mgmt_util'.freeze

  def initialize
    @username, @password, @openssl_conf, @timestamp = initialize_settings
    output = File.open("saml_#{@timestamp}.txt", 'w')
    @kmu = Greenletters::Process.new(KEY_MGMT_UTIL, transcript: output)
    @kmu.start!
    @kmu.wait_for(:output, /Command:/)
  end

  def generate_saml_key
    saml_label = create_key_and_crt_files
    login_to_hsm
    wrapping_key_handle = generate_symmetric_wrapping_key
    import_private_key(saml_label, wrapping_key_handle)
    exit_hsm
    saml_label
  end

  def cleanup
    File.delete("saml_#{@timestamp}.crt")
    File.delete("saml_#{@timestamp}.txt")
    File.delete("saml_#{@timestamp}.key")
  end

  private

  def initialize_settings
    username, password = prompt_for_username_and_password
    openssl_conf = prompt_for_openssl_conf
    time = Time.respond_to?(:zone) ? Time.zone : Time
    timestamp = time.now.strftime('%Y%m%d%H%M%S')
    [username, password, openssl_conf, timestamp]
  end

  def create_key_and_crt_files
    saml_label = Shellwords.shellescape("saml_#{@timestamp}")
    openssl_conf = Shellwords.shellescape(@openssl_conf)
    cmd = "openssl req -x509 -nodes -sha256 -days 365 " \
           " -newkey rsa:2048 -keyout #{saml_label}.key " \
           "-out #{saml_label}.crt -config #{openssl_conf}"
    result = system(cmd)
    raise 'Call to openssl failed' unless result
    saml_label
  end

  def login_to_hsm
    @kmu << "loginHSM -u CU -s #{@username} -p #{@password}\n"
    @kmu.wait_for(:output, /SUCCESS/)
  end

  def generate_symmetric_wrapping_key
    @kmu << "genSymKey -t 31 -s 16 -sess -l wrapping_key_for_import\n"
    wrapping_key_handle = wait_for_wrapping_key_handle
    @kmu.wait_for(:output, /SUCCESS/)
    wrapping_key_handle
  end

  def wait_for_wrapping_key_handle
    wrapping_key_handle = nil
    @kmu.wait_for(:output, /Key Handle: \d+/) do |_process, matching|
      matching.matched =~ /Key Handle: (\d+)/
      wrapping_key_handle = Regexp.last_match[1]
    end
    wrapping_key_handle
  end

  def import_private_key(saml_label, wrapping_key_handle)
    @kmu << "importPrivateKey -f #{saml_label}.key -l #{saml_label} -w #{wrapping_key_handle}\n"
    @kmu.wait_for(:output, /SUCCESS/)
  end

  def exit_hsm
    @kmu << 'exit'
    Kernel.puts "Certificate written to 'saml_#{@timestamp}.crt'.\n" \
         "Transcript written to 'saml_#{@timestamp}.txt'.\n" \
         "Key generation complete.\n"
  end

  def prompt_for_username_and_password
    Kernel.puts 'Please enter the CloudHSM username used for generating a new SAML key'
    username = user_input
    Kernel.puts 'Please enter the corresponding password'
    password = STDIN.noecho(&:gets).chomp
    [username, password]
  end

  def prompt_for_openssl_conf
    Kernel.puts 'Please enter the full path to openssl.conf'
    openssl_conf = user_input
    raise 'openssl.conf not found' unless File.exist?(openssl_conf)
    openssl_conf
  end

  def user_input
    gets.chomp
  end
end

CloudhsmKeyGenerator.new.generate_saml_key if $PROGRAM_NAME == __FILE__
