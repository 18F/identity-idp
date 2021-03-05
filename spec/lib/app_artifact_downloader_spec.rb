require 'rails_helper'

RSpec.describe AppArtifactDownloader do
  let(:artifacts_list) { ['test-1', 'test-2', 'test-3'] }
  let(:artifacts_destination) { 'tmp/artifacts-test' }
  let(:artifacts_destination_absolute) { Rails.root.join(artifacts_destination) }

  subject(:downloader) do
    described_class.new(
      artifacts: artifacts_list,
      destination: artifacts_destination,
    )
  end

  before do
    cleanup_artifacts_test_folder
  end

  after do
    cleanup_artifacts_test_folder
  end

  describe '#download' do
    context 'when running in local dev' do
      before do
        allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(false)
      end

      it 'is a noop' do
        expect(Aws::S3::Client).to_not receive(:new)
        expect(Aws::STS::Client).to_not receive(:new)

        downloader.download

        expect(File.directory?(artifacts_destination_absolute)).to eq(false)
      end
    end

    context 'when running in a data center' do
      let(:s3_client_stub) { Aws::S3::Client.new(stub_responses: true) }
      let(:sts_client_stub) { Aws::STS::Client.new(stub_responses: true) }

      before do
        allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)
        allow(Identity::Hostdata).to receive(:env).and_return('fancy-test-env')

        s3_client_stub.stub_responses(
          :get_object,
          { body: 'test-1-body' },
          { body: 'test-2-body' },
          { body: 'test-3-body' },
        )
        sts_client_stub.stub_responses(:get_caller_identity, account: '1234')

        allow(downloader).to receive(:s3_client).and_return(s3_client_stub)
        allow(downloader).to receive(:sts_client).and_return(sts_client_stub)
      end

      it 'downloads all of the artifacts and writes them to tmp' do
        expect(File.directory?(artifacts_destination_absolute)).to eq(false)

        downloader.download

        expect(File.directory?(artifacts_destination_absolute)).to eq(true)

        expect(File.read(artifacts_destination_absolute.join('test-1'))).to eq('test-1-body')
        expect(File.read(artifacts_destination_absolute.join('test-2'))).to eq('test-2-body')
        expect(File.read(artifacts_destination_absolute.join('test-3'))).to eq('test-3-body')

        expected_bucket_name = 'login-gov.secrets.1234-us-west-2'
        s3_requests = s3_client_stub.api_requests
        expect(s3_requests[0][:params]).to eq(
          bucket: expected_bucket_name, key: 'fancy-test-env/test-1',
        )
        expect(s3_requests[1][:params]).to eq(
          bucket: expected_bucket_name, key: 'fancy-test-env/test-2',
        )
        expect(s3_requests[2][:params]).to eq(
          bucket: expected_bucket_name, key: 'fancy-test-env/test-3',
        )
      end

      it 'does not error if the artifacts folder already exists' do
        FileUtils.mkdir_p(artifacts_destination_absolute)

        downloader.download
      end
    end
  end

  def cleanup_artifacts_test_folder
    if File.directory?(artifacts_destination_absolute)
      FileUtils.remove_dir(artifacts_destination_absolute)
    end
  end
end
