require 'rails_helper'
require 'cloudhsm/cloudhsm_key_generator'

describe CloudhsmKeyGenerator do
  let(:subject) { CloudhsmKeyGenerator.new }
  before(:each) { mock_cloudhsm }

  describe '#generate_saml_key' do
    it 'generates saml secret key, crt, and transcript' do
      label = subject.generate_saml_key
      saml_key = "#{label}.key"
      saml_crt = "#{label}.crt"
      transcript = "#{label}.txt"

      expect(File.exist?(saml_key)).to eq(true)
      expect(File.exist?(saml_crt)).to eq(true)
      expect(File.exist?(transcript)).to eq(true)

      subject.cleanup
    end

    it 'raises an error if the openssl call fails' do
      allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).and_return(__FILE__)
      expect { subject.generate_saml_key }.to raise_error(RuntimeError, 'Call to openssl failed')
    end

    it 'raises an error if the openssl.conf is not found' do
      allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).and_return('filenotfound')

      expect { subject.generate_saml_key }.to raise_error(RuntimeError, 'openssl.conf not found')
    end

    it 'creates a saml key label with a 12 digit timestamp' do
      label = subject.generate_saml_key

      expect(label =~ /\d{1,12}/).to_not be_nil

      subject.cleanup
    end
  end

  describe '#cleanup' do
    it 'removes all the files if we request cleanup' do
      label = subject.generate_saml_key
      subject.cleanup

      saml_key = "#{label}.key"
      saml_crt = "#{label}.crt"
      transcript = "#{label}.txt"
      expect(File.exist?(saml_key)).to eq(false)
      expect(File.exist?(saml_crt)).to eq(false)
      expect(File.exist?(transcript)).to eq(false)
    end
  end

  def mock_cloudhsm
    allow(STDIN).to receive(:noecho).and_return('password')
    allow_any_instance_of(Greenletters::Process).to receive(:wait_for).and_return(true)
    allow_any_instance_of(Greenletters::Process).to receive(:<<).and_return(true)
    allow_any_instance_of(CloudhsmKeyGenerator).to receive(:user_input).
      and_return('config/openssl.conf')
  end
end
