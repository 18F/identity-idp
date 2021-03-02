require 'rails_helper'
describe 'AwsS3Helper' do
  let(:session_uuid) { SecureRandom.uuid }
  let(:env) { 'dev' }
  let(:account_id) { '123456789' }
  let(:region) { 'us-west-2' }
  let(:prefix) { 'login-gov-idp-doc-capture' }
  let(:image_type) { 'front' }
  let(:bucket) { "#{prefix}-#{env}.#{account_id}-#{region}" }
  let(:query_keys) do
    %w[
      X-Amz-Algorithm
      X-Amz-Credential
      X-Amz-Date
      X-Amz-Expires
      X-Amz-SignedHeaders
      X-Amz-Signature
    ]
  end

  before do
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_raise(Net::OpenTimeout)
  end

  describe '#s3_presigned_url' do
    before do
      client_stub = Aws::S3::Client.new(region: region, stub_responses: true)
      client_stub.stub_responses(:list_buckets, { buckets: [{ name: bucket }] })
      resource_stub = Aws::S3::Resource.new(client: client_stub)
      allow(Identity::Hostdata).
        to receive(:env).and_return(env)
      allow(helper).to receive(:s3_resource).and_return(resource_stub)
    end

    it 'returns a URL' do
      url = URI(
        helper.s3_presigned_url(
          bucket_prefix: prefix,
          keyname: "#{session_uuid}-#{image_type}",
        ),
      )
      query = Hash[*url.query.split(/[&=]/)]

      expect(url.host).to eq("s3.#{region}.amazonaws.com")
      expect(url.path).to eq("/#{bucket}/#{session_uuid}-#{image_type}")
      expect(query['X-Amz-Algorithm']).to eq('AWS4-HMAC-SHA256')
      expect(query.keys).to match_array(query_keys)
    end

    it 'requires a keyname' do
      expect { helper.s3_presigned_url(bucket_prefix: prefix, keyname: '') }.
        to raise_error(ArgumentError, 'keyname is required')
    end

    it 'requires a bucket_prefix' do
      expect { helper.s3_presigned_url(bucket_prefix: '', keyname: 'image_type') }.
        to raise_error(ArgumentError, 'bucket_prefix is required')
    end
  end

  describe '#s3_resource' do
    context 'AWS credentials are not set' do
      before do
        allow(Aws::S3::Resource).to receive(:new).
          and_raise(Aws::Sigv4::Errors::MissingCredentialsError, 'Credentials not set')
      end

      it 'returns nil' do
        expect(helper.s3_resource).to be_nil
      end
    end
  end
end
