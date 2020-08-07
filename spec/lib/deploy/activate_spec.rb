require 'rails_helper'
require 'fakefs/spec_helpers'
require 'login_gov/hostdata/fake_s3_client'
require Rails.root.join('lib', 'deploy', 'activate.rb')

describe Deploy::Activate do
  let(:config_dir) { Rails.root.join('tmp') }

  around(:each) do |ex|
    LoginGov::Hostdata.reset!

    @logger = Logger.new('/dev/null')
    File.delete(env_yaml_path) if File.exist?(env_yaml_path)
    File.delete(result_yaml_path) if File.exist?(result_yaml_path)

    ex.run
  end

  let(:logger) { @logger }
  let(:s3_client) { LoginGov::Hostdata::FakeS3Client.new }
  let(:set_up_files!) {}

  let(:result_yaml_path) { config_dir.join('s3.yml') }
  let(:env_yaml_path) { config_dir.join('env.yml') }
  let(:subject) { Deploy::Activate.new(logger: logger, s3_client: s3_client, result_yaml_path: result_yaml_path,
                                       env_yaml_path: env_yaml_path) }

  context 'in a deployed production environment' do
    before do
      allow(LoginGov::Hostdata).to receive(:env).and_return('int')

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

      # for now, stub cloning identity-idp-config
      allow(subject).to receive(:clone_idp_config)
      allow(subject).to receive(:setup_idp_config_symlinks)
    end

    let(:application_yml) do
      <<~YAML
        production:
          usps_confirmation_max_days: '5'
      YAML
    end

    it 'downloads configs from s3' do
      subject.run

      expect(File.exist?(result_yaml_path)).to eq(true)
    end

    it 'merges the application.yml from s3 over the application.yml.default' do
      subject.run

      combined_application_yml = YAML.load_file(result_yaml_path)

      # top-level key from application.yml.default
      expect(combined_application_yml['recovery_code_length']).to eq('4')
      # overridden production key from s3
      expect(combined_application_yml['production']['usps_confirmation_max_days']).to eq('5')
      # production key from application.yml.example, not overwritten
      expect(combined_application_yml['production']['lockout_period_in_minutes']).to eq('10')
    end

    it 'sets the correct permissions on the YAML files' do
      subject.run

      application_yml = File.new(result_yaml_path)
      expect(application_yml.stat.mode.to_s(8)).to eq('100640')

      application_env_yml = File.new(env_yaml_path)
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

      # for now, stub cloning identity-idp-config
      allow(subject).to receive(:clone_idp_config)
      allow(subject).to receive(:setup_idp_config_symlinks)
    end

    it 'errors' do
      expect { subject.run }.to raise_error(Net::OpenTimeout)
    end
  end
end
