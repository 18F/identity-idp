require 'rails_helper'
require 'cloudhsm/cloudhsm_key_generator'

describe CloudhsmKeyGenerator do
  let(:subject) { CloudhsmKeyGenerator.new }
  let(:wrapping_key) { '1234' }
  let(:key_owner_name) { 'username' }
  let(:key_owner_password) { 'password' }
  let(:share_with_username) { 'username2' }
  let(:key_handle) { '5678' }

  before(:each) { mock_cloudhsm }

  around(:each) do |example|
    suppress_output do
      example.run
    end
  end

  describe '#generate_saml_key' do
    it 'generates saml secret key, crt, and transcript' do
      greenletters = mock_cloudhsm
      label, handle = subject.generate_saml_key
      saml_key = "#{label}.key"
      saml_crt = "#{label}.crt"
      transcript = "#{label}.txt"
      secrets_fn = "#{label}.scr"

      expect(greenletters).to have_received(:<<).
        with("loginHSM -u CU -s #{key_owner_name} -p #{key_owner_password}\n").once
      expect(greenletters).to have_received(:<<).
        with("genSymKey -t 31 -s 16 -sess -l wrapping_key_for_import\n").once
      expect(greenletters).to have_received(:<<).
        with("importPrivateKey -f #{label}.key -l #{label} -w #{wrapping_key}\n").once
      expect(greenletters).to have_received(:<<).with("exit\n").once

      expect(handle).to eq(key_handle)
      expect(File.exist?(saml_key)).to eq(true)
      expect(File.exist?(saml_crt)).to eq(true)
      expect(File.exist?(transcript)).to eq(true)

      expect(File.read(secrets_fn)).
        to eq("#{key_owner_name}:#{key_owner_password}:#{key_handle}:#{share_with_username}\n")
      cleanup(label)
    end

    it 'raises an error if the openssl call fails' do
      allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).and_return(__FILE__)

      label = nil
      expect do
        label, _handle = subject.generate_saml_key
      end.to raise_error(RuntimeError, 'Call to openssl failed')

      cleanup(label)
    end

    it 'raises an error if the openssl.conf is not found' do
      allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).
        and_return(key_owner_name, 'bad_filename', share_with_username)

      label = nil
      expect { label, _handle = subject.generate_saml_key }.
        to raise_error(RuntimeError, 'openssl.conf not found at (bad_filename)')

      cleanup(label)
    end

    it 'creates a saml key label with a 12 digit timestamp' do
      label, _handle = subject.generate_saml_key

      expect(label =~ /\d{1,12}/).to_not be_nil

      cleanup(label)
    end
  end

  def mock_cloudhsm
    allow(STDIN).to receive(:noecho).and_return(key_owner_password)

    greenletters = instance_double(Greenletters::Process)
    allow(Greenletters::Process).to receive(:new).and_return(greenletters)
    allow(greenletters).to receive(:start!).and_return(true)
    allow(greenletters).to receive(:wait_for).and_return(true)
    allow(greenletters).to receive(:<<).and_return(true)
    allow(greenletters).to receive(:wait_for).with(:output, /Key Handle: \d+/).
      and_yield(nil, StringScanner.new(''))
    allow_any_instance_of(StringScanner).to receive(:matched).
      and_return("Key Handle: #{wrapping_key}\n", "Key Handle: #{key_handle}\n")

    allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).
      and_return(key_owner_name, 'config/openssl.conf', share_with_username)

    greenletters
  end

  def cleanup(label)
    safe_delete("#{label}.crt")
    safe_delete("#{label}.txt")
    safe_delete("#{label}.key")
    safe_delete("#{label}.scr")
  end

  def safe_delete(fn)
    File.delete(fn) if File.exist?(fn)
  end
end
