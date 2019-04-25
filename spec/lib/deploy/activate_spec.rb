require 'rails_helper'
require 'fakefs/spec_helpers'
require 'login_gov/hostdata/fake_s3_client'
require Rails.root.join('lib', 'deploy', 'activate.rb')

describe Deploy::Activate do
  let(:config_dir) { Rails.root.join('config') }

  around(:each) do |ex|
    LoginGov::Hostdata.reset!

    @logger = Logger.new('/dev/null')

    FakeFS do
      FakeFS::FileSystem.clone(config_dir)

      ex.run
    end
  end

  let(:logger) { @logger }
  let(:s3_client) { LoginGov::Hostdata::FakeS3Client.new }
  let(:set_up_files!) {}

  let(:subject) { Deploy::Activate.new(logger: logger, s3_client: s3_client) }

  context 'in a deployed production environment' do
    before do
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'region' => 'us-west-1',
          'accountId' => '12345',
        }.to_json)

      s3_client.put_object(
        bucket: 'login-gov.app-secrets.12345-us-west-1',
        key: '/int/idp/v1/application.yml',
        body: application_yml,
      )

      FileUtils.mkdir_p('/etc/login.gov/info')
      File.open('/etc/login.gov/info/env', 'w') { |file| file.puts 'int' }
    end

    let(:application_yml) do
      <<~YAML
        production:
          usps_confirmation_max_days: '5'
      YAML
    end

    it 'downloads configs from s3' do
      subject.run

      expect(File.exist?(File.join(config_dir, 'application.yml'))).to eq(true)
    end

    it 'merges the application.yml from s3 over the application.yml.default' do
      subject.run

      combined_application_yml = YAML.load_file(File.join(config_dir, 'application.yml'))

      # top-level key from application.yml.default
      expect(combined_application_yml['recovery_code_length']).to eq('4')
      # overridden production key from s3
      expect(combined_application_yml['production']['usps_confirmation_max_days']).to eq('5')
      # production key from applicaiton.yml.example, not overwritten
      expect(combined_application_yml['production']['lockout_period_in_minutes']).to eq('10')
    end

    it 'sets the correct permissions on the YAML files' do
      subject.run

      application_yml = File.new(File.join(config_dir, 'application.yml'))
      expect(application_yml.stat.mode.to_s(8)).to eq('100640')

      application_env_yml = File.new(File.join(config_dir, 'application_s3_env.yml'))
      expect(application_env_yml.stat.mode.to_s(8)).to eq('100640')
    end

    it 'uses a default logger with a progname' do
      subject = Deploy::Activate.new(s3_client: s3_client)

      expect(subject.logger.progname).to eq('deploy/activate')
    end
  end

  context 'outside a deployed production environment' do
    before do
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_timeout
    end

    it 'errors' do
      expect { subject.run }.to raise_error(Net::OpenTimeout)
    end
  end
end
