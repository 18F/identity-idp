require 'rails_helper'

RSpec.describe AppConfigReader do
  DEFAULT_YAML = <<~HEREDOC
    config1: 'test'
    config2: 'override me'
  HEREDOC
  OVERRIDE_YAML = <<~HEREDOC
    config2: 'overriden value'
  HEREDOC
  ROLE_YAML = <<~HEREDOC
    role_config: 'test'
  HEREDOC

  around(:each) do |ex|
    Dir.mktmpdir do |root|
      set_tmp_dir_fixtures(root)
      reader.root_path = root
      ex.run
    end
  end

  let(:logger) { Logger.new('/dev/null') }
  let(:s3_client) { nil }
  subject(:reader) { AppConfigReader.new(logger: logger, s3_client: s3_client) }

  context 'in the datacenter' do
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:s3_contents) do
      {
        'int/idp/v1/application.yml' => OVERRIDE_YAML,
      }
    end

    before do
      allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)
      allow(Identity::Hostdata).to receive(:instance_role).and_return('idp')
      allow(Identity::Hostdata).to receive(:env).and_return('int')

      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'region' => 'us-west-1',
          'accountId' => '12345',
        }.to_json)

      s3_client.stub_responses(
        :get_object, proc do |context|
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
    end

    it 'merges the default and override yaml values' do
      configuration = reader.read_configuration

      expect(s3_client).to have_received(:get_object).with(
        hash_including(key: 'int/idp/v1/application.yml'),
      )
      expect(configuration['config1']).to eq('test')
      expect(configuration['config2']).to eq('overriden value')
    end

    it 'applies the role configs if they exist' do
      s3_contents['int/idp/v1/web.yml'] = ROLE_YAML

      configuration = reader.read_configuration

      expect(s3_client).to have_received(:get_object).with(
        hash_including(key: 'int/idp/v1/application.yml'),
      )
      expect(s3_client).to have_received(:get_object).with(
        hash_including(key: 'int/idp/v1/web.yml'),
      )
      expect(configuration['config1']).to eq('test')
      expect(configuration['config2']).to eq('overriden value')
    end
  end

  context 'during local dev' do
    it 'merges the default and override configurations' do
      configuration = reader.read_configuration

      expect(configuration['config1']).to eq('test')
      expect(configuration['config2']).to eq('overriden value')
    end
  end

  def set_tmp_dir_fixtures(root)
    FileUtils.mkdir_p(File.join(root, 'config'))
    File.write(File.join(root, 'config', 'application.yml.default'), DEFAULT_YAML)
    File.write(File.join(root, 'config', 'application.yml'), OVERRIDE_YAML)
  end
end
