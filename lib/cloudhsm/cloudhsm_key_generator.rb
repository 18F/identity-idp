require 'greenletters'
require 'io/console'

# In prod this script is run through the cloudhsm rake task which will run on a RamDisk
# generates saml_<timestamp>.key, saml_<timestamp>.crt
# saml_<timestamp>.scr (cached credentials and key handle for the key_sharer script)
# and saml_<timestamp>.txt (a transcript of the cloudhsm interaction)
# the program interactively asks for username, password (hidden), idp username,
# and openssl.conf location

class CloudhsmKeyGenerator # rubocop:disable Metrics/ClassLength
  KEY_MGMT_UTIL = '/opt/cloudhsm/bin/key_mgmt_util'.freeze

  def initialize
    @username, @password, @openssl_conf, @timestamp = initialize_settings
    @idp_username = prompt_for_idp_username
    @kmu = run_key_mgmt_util
    wait_for_command_to_finish
  end

  def generate_saml_key
    saml_label = create_key_and_crt_files
    login_to_hsm
    key_handle = import_private_key(saml_label)
    exit_hsm
    cache_credentials_and_private_key_handle(key_handle)
    [saml_label, key_handle]
  end

  private

  def import_private_key(saml_label)
    wrapping_key_handle = generate_symmetric_wrapping_key
    import_wrapped_key(saml_label, wrapping_key_handle)
  end

  def run_key_mgmt_util
    output = File.open("saml_#{@timestamp}.txt", 'w')
    kmu = Greenletters::Process.new(KEY_MGMT_UTIL, transcript: output)
    kmu.start!
    kmu
  end

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
    wait_for_command_to_finish
  end

  def generate_symmetric_wrapping_key
    @kmu << "genSymKey -t 31 -s 16 -sess -l wrapping_key_for_import\n"
    @kmu.wait_for(:output, /SUCCESS/)
    wait_for_wrapping_key_handle
  end

  def wait_for_wrapping_key_handle
    wrapping_key_handle = nil
    @kmu.wait_for(:output, /Key Handle: \d+/) do |_process, matching|
      matching.matched =~ /Key Handle: (\d+)/
      wrapping_key_handle = Regexp.last_match[1]
    end
    wait_for_command_to_finish
    wrapping_key_handle
  end

  def import_wrapped_key(saml_label, wrapping_key_handle)
    @kmu << "importPrivateKey -f #{saml_label}.key -l #{saml_label} -w #{wrapping_key_handle}\n"
    @kmu.wait_for(:output, /SUCCESS/)
    wait_for_private_key_handle
  end

  def wait_for_private_key_handle
    key_handle = nil
    @kmu.wait_for(:output, /Key Handle: \d+/) do |_process, matching|
      matching.matched =~ /Key Handle: (\d+)/
      key_handle = Regexp.last_match[1]
    end
    wait_for_command_to_finish
    key_handle
  end

  def exit_hsm
    @kmu << "exit\n"
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

  def prompt_for_idp_username
    Kernel.puts 'Please enter the CloudHSM username used by the IDP'
    user_input
  end

  def prompt_for_openssl_conf
    Kernel.puts 'Please enter the full path to openssl.conf'
    openssl_conf = user_input
    raise "openssl.conf not found at (#{openssl_conf})" unless File.exist?(openssl_conf)
    openssl_conf
  end

  def user_input
    gets.chomp
  end

  def wait_for_command_to_finish
    @kmu.wait_for(:output, /Command:/)
  end

  def cache_credentials_and_private_key_handle(key_handle)
    File.open("saml_#{@timestamp}.scr", 'w') do |file|
      file.puts("#{@username}:#{@password}:#{key_handle}:#{@idp_username}")
    end
  end
end

CloudhsmKeyGenerator.new.generate_saml_key if $PROGRAM_NAME == __FILE__

# Command:  loginHSM -u CU -s username -p password

# Cfm3LoginHSM returned: 0x00 : HSM Return: SUCCESS

# Cluster Error Status
# Node id 1 and err state 0x00000000 : HSM Return: SUCCESS

# Command:  genSymKey -t 31 -s 16 -sess -l wrapping_key_for_import

# Cfm3GenerateSymmetricKey returned: 0x00 : HSM Return: SUCCESS

# Symmetric Key Created.  Key Handle: 1234

# Cluster Error Status
# Node id 1 and err state 0x00000000 : HSM Return: SUCCESS

# Command:  importPrivateKey -f saml_20180721214537.key -l saml_20180721214537 -w 1234
# BER encoded key length is 1218

# Cfm3WrapHostKey returned: 0x00 : HSM Return: SUCCESS

# Cfm3CreateUnwrapTemplate returned: 0x00 : HSM Return: SUCCESS

# Cfm3UnWrapKey returned: 0x00 : HSM Return: SUCCESS

# Private Key Imported.  Key Handle: 5678

# Cluster Error Status
# Node id 1 and err state 0x00000000 : HSM Return: SUCCESS
