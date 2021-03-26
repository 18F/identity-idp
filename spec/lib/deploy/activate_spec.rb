require 'rails_helper'
require Rails.root.join('lib', 'deploy', 'activate.rb')

describe Deploy::Activate do
  let(:root) { @root }

  around(:each) do |ex|
    Identity::Hostdata.reset!

    Dir.mktmpdir do |dir|
      @root = dir
      ex.run
    end
  end

  let(:logger) { Logger.new('/dev/null') }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:set_up_files!) {}
  let(:instance_role) { 'idp' }

  let(:result_yaml_path) { File.join(root, 'config', 'application.yml') }
  let(:env_yaml_path) { File.join(root, 'config', 'application_s3_env.yml') }
  let(:geolite_path) { File.join(root, 'geo_data', 'GeoLite2-City.mmdb') }
  let(:pwned_passwords_path) { File.join(root, 'pwned_passwords', 'pwned_passwords.txt') }

  let(:subject) do
    Deploy::Activate.new(
      logger: logger,
      s3_client: s3_client,
      root: root,
    )
  end

  context 'in a deployed production environment' do
    before do
      allow(Identity::Hostdata).to receive(:env).and_return('int')
      allow(Identity::Hostdata).to receive(:instance_role).and_return(instance_role)

      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'region' => 'us-west-1',
          'accountId' => '12345',
        }.to_json)

      s3_client.stub_responses(:get_object, proc do |context|
          key = context.params[:key]
          body = s3_contents[key]
          if body.present?
            { body: body }
          else
            raise Aws::S3::Errors::NoSuchKey.new(nil, nil)
          end
        end
      )
      allow(s3_client).to receive(:get_object).and_call_original

      # for now, stub cloning identity-idp-config
      allow(subject).to receive(:clone_idp_config)
      allow(subject).to receive(:setup_idp_config_symlinks)
    end

    let(:s3_contents) do
      {
        'int/idp/v1/application.yml' => application_yml,
        'common/GeoIP2-City.mmdb' => geolite_content,
        'common/pwned-passwords.txt' => pwned_passwords_content,
      }
    end

    let(:application_yml) do
      <<~YAML
        production:
          usps_confirmation_max_days: '5'
      YAML
    end
    let(:geolite_content) { 'geolite test' }
    let(:pwned_passwords_content ) { 'pwned passwords test' }

    it 'downloads configs from s3' do
      subject.run

      expect(s3_client).to have_received(:get_object).with(
        bucket: 'login-gov.app-secrets.12345-us-west-1',
        key: 'int/idp/v1/application.yml',
      )

      expect(File.exist?(result_yaml_path)).to eq(true)
      expect(File.read(result_yaml_path)).to include("usps_confirmation_max_days: '5'")
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

    context 'on a web instance' do
      let(:instance_role) { 'idp' }

      context 'when web.yml exists in s3' do
        before do
          s3_contents['int/idp/v1/web.yml'] = <<~YAML
            web_yaml_value: 'true'
          YAML
        end

        it 'merges web.yml into application.yml' do
          subject.run

          expect(File.exist?("#{root}/config/web.yml")).to eq(true)

          combined_application_yml = YAML.load_file(result_yaml_path)
          expect(combined_application_yml['web_yaml_value']).to eq('true')
        end
      end

      context 'when web.yml does not exist in s3' do
        it 'warns and leaves application.yml as-is' do
          expect(logger).to receive(:warn).with(/web.yml/)

          expect { subject.run }.to_not raise_error

          expect(File.exist?("#{root}/config/web.yml")).to eq(false)

          combined_application_yml = YAML.load_file(result_yaml_path)
          expect(combined_application_yml).to_not have_key('web_yaml_value')
        end
      end
    end

    context 'on a worker instance' do
      let(:instance_role) { 'worker' }

      context 'when worker.yml exists in s3' do
        before do
          s3_contents['int/idp/v1/worker.yml'] = <<~YAML
            worker_yaml_value: 'true'
          YAML
        end

        it 'merges worker.yml into application.yml' do
          subject.run

          expect(File.exist?("#{root}/config/worker.yml")).to eq(true)

          combined_application_yml = YAML.load_file(result_yaml_path)
          expect(combined_application_yml['worker_yaml_value']).to eq('true')
        end
      end

      context 'when worker.yml does not exist in s3' do
        it 'warns and leaves application.yml as-is' do
          expect(logger).to receive(:warn).with(/worker.yml/)

          expect { subject.run }.to_not raise_error

          expect(File.exist?("#{root}/config/worker.yml")).to eq(false)

          combined_application_yml = YAML.load_file(result_yaml_path)
          expect(combined_application_yml).to_not have_key('worker_yaml_value')
        end
      end
    end

    it 'sets the correct permissions on the YAML files' do
      subject.run

      application_yml = File.new(result_yaml_path)
      expect(application_yml.stat.mode.to_s(8)).to eq('100640')

      application_env_yml = File.new(env_yaml_path)
      expect(application_env_yml.stat.mode.to_s(8)).to eq('100640')
    end

    it 'downloads the pwned passwords and geolite files from s3' do
      subject.run

      expect(s3_client).to have_received(:get_object).with(
        bucket: 'login-gov.secrets.12345-us-west-1',
        key: 'common/GeoIP2-City.mmdb',
      )
      expect(s3_client).to have_received(:get_object).with(
        bucket: 'login-gov.secrets.12345-us-west-1',
        key: 'common/pwned-passwords.txt',
      )

      expect(File.read(geolite_path)).to eq(geolite_content)
      expect(File.read(pwned_passwords_path)).to eq(pwned_passwords_content)
    end

    it 'does not re-download GeoIP files if they already exist' do
      FileUtils.mkdir_p(File.dirname(geolite_path))
      File.write(geolite_path, 'existing geolite tests')

      expect { subject.run }.to_not(change { File.read(geolite_path) })
    end

    it 'does not re-download pwned password files if they already exist' do
      FileUtils.mkdir_p(File.dirname(pwned_passwords_path))
      File.write(pwned_passwords_path, 'existing pwned passwords')

      expect { subject.run }.to_not(change { File.read(pwned_passwords_path) })
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
