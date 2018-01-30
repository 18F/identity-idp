require 'spec_helper'
require 'fakefs/spec_helpers'
require 'login_gov/hostdata/fake_s3_client'

load File.expand_path('../../deploy/activate', File.dirname(__FILE__))

RSpec.describe 'deploy/activate' do
  let(:app_root) { File.expand_path('../../', File.dirname(__FILE__)) }
  let(:config_dir) { File.join(app_root, 'config') }

  around(:each) do |ex|
    LoginGov::Hostdata.reset!

    @logger = Logger.new('/dev/null')

    FakeFS do
      FakeFS::FileSystem.clone(config_dir)

      ex.run
    end
  end

  subject(:script) { Deploy::Activate.new(logger: logger, s3_client: s3_client) }

  let(:logger) { @logger }
  let(:s3_client) { LoginGov::Hostdata::FakeS3Client.new }
  let(:set_up_files!) {}

  describe '#run' do
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
          body: application_yml
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
        script.run

        expect(File.exist?(File.join(config_dir, 'application.yml'))).to eq(true)
      end

      it 'merges the application.yml from s3 over the application.yml.example' do
        script.run

        combined_application_yml = YAML.load_file(File.join(config_dir, 'application.yml'))

        # top-level key from application.yml.example
        expect(combined_application_yml['recovery_code_length']).to eq('4')
        # overridden production key from s3
        expect(combined_application_yml['production']['usps_confirmation_max_days']).to eq('5')
        # production key from applicaiton.yml.example, not overwritten
        expect(combined_application_yml['production']['lockout_period_in_minutes']).to eq('10')
      end

      it 'sets the correct permissions on the YAML files' do
        script.run

        application_yml = File.new(File.join(config_dir, 'application.yml'))
        expect(application_yml.stat.mode.to_s(8)).to eq('100640')

        application_env_yml = File.new(File.join(config_dir, 'application_s3_env.yml'))
        expect(application_env_yml.stat.mode.to_s(8)).to eq('100640')
      end
    end

    context 'outside a deployed production environment' do
      before do
        stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          to_timeout
      end

      it 'errors' do
        expect { script.run }.to raise_error(Net::OpenTimeout)
      end
    end
  end

  describe '#default_logger' do
    it 'sets the progname' do
      expect(script.default_logger.progname).to eq('deploy/activate')
    end
  end
end
