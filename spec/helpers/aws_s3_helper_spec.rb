require 'rails_helper'
describe 'AwsS3Helper' do
  let(:session_uuid) { SecureRandom.uuid }
  let(:env) { 'dev' }
  let(:account_id) { '123456789' }
  let(:region) { 'us-west-2' }
  let(:prefix) { 'login-gov-idp-doc-capture' }
  let(:image_type) { 'front' }
  let(:bucket) { "#{prefix}-#{env}.#{account_id}-#{region}" }
  let(:host) { "s3.#{region}.amazonaws.com" }
  let(:path) { "/#{bucket}/#{session_uuid}-#{image_type}" }
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
    client_stub = Aws::S3::Client.new(region: region, stub_responses: true)
    client_stub.stub_responses(:list_buckets, { buckets: [{ name: bucket }] })
    resource_stub = Aws::S3::Resource.new(client: client_stub)
    allow(LoginGov::Hostdata).
      to receive(:env).and_return(env)
    allow(LoginGov::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    allow(helper).to receive(:s3_resource).and_return(resource_stub)
  end

  describe '#s3_presigned_url' do
    it 'returns a URL' do
      url = URI(
        helper.s3_presigned_url(
          bucket_prefix: prefix,
          keyname: "#{session_uuid}-#{image_type}",
        ),
      )
      query = Hash[*url.query.split(/[&=]/)]

      expect(url.host).to eq(host)
      expect(url.path).to eq(path)
      expect(query['X-Amz-Algorithm']).to eq('AWS4-HMAC-SHA256')
      expect(Set[*query.keys]).to eq(Set[*query_keys])
    end
  end
end
