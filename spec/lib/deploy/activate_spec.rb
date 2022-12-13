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

      ec2_api_token = SecureRandom.hex

      stub_request(:put, 'http://169.254.169.254/latest/api/token').
        to_return(body: ec2_api_token)

      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        with(headers: { 'X-aws-ec2-metadata-token' => ec2_api_token }).
        to_return(body: {
          'region' => 'us-west-1',
          'accountId' => '12345',
        }.to_json)

      s3_client.stub_responses(
        :get_object,
        proc do |context|
          key = context.params[:key]
          body = s3_contents[key]
          if body.present?
            { body: body }
          else
            raise Aws::S3::Errors::NoSuchKey.new(nil, nil)
          end
        end,
      )
      allow(s3_client).to receive(:get_object).and_call_original

      # for now, stub cloning identity-idp-config
      allow(subject).to receive(:clone_idp_config)
      allow(subject).to receive(:setup_idp_config_symlinks)
    end

    let(:s3_contents) do
      {
        'common/GeoIP2-City.mmdb' => geolite_content,
        'common/pwned-passwords.txt' => pwned_passwords_content,
      }
    end

    let(:geolite_content) { 'geolite test' }
    let(:pwned_passwords_content) { 'pwned passwords test' }

    it 'downloads the pwned passwords and geolite files from s3' do
      subject.run

      expect(s3_client).to have_received(:get_object).with(
        bucket: 'login-gov.secrets.12345-us-west-1',
        key: 'common/GeoIP2-City.mmdb',
        response_target: kind_of(String),
      )
      expect(s3_client).to have_received(:get_object).with(
        bucket: 'login-gov.secrets.12345-us-west-1',
        key: 'common/pwned-passwords.txt',
        response_target: kind_of(String),
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
      stub_request(:put, 'http://169.254.169.254/latest/api/token').
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
