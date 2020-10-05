require 'rails_helper'
describe 'AwsS3Helper' do
  let(:session_uuid) { SecureRandom.uuid }
  let(:env) { 'dev' }
  let(:account_id) { '123456789' }
  let(:region) { 'us-west-2' }
  let(:prefix) { 'login-gov-idp-doc-capture' }
  let(:image_type) { 'front' }
  let(:bucket) { "#{prefix}-#{env}.#{account_id}-#{region}" }
  let(:expected_url_regex) do
    regex_string = "https:\/\/s3.#{region}.amazonaws.com\/" \
      "#{bucket}\/" \
      "#{session_uuid}-#{image_type}\\?" \
      "X-Amz-Algorithm=AWS4-HMAC-SHA256&" \
      "X-Amz-Credential=.+&" \
      "X-Amz-Date=\\w+&" \
      "X-Amz-Expires=900&" \
      "X-Amz-SignedHeaders=host&" \
      "X-Amz-Signature=\\w+\\z"
    Regexp.new regex_string
  end
  let(:mock_url) do
    "https://s3.#{region}.amazonaws.com/" \
      "#{bucket}/" \
      "#{session_uuid}-#{image_type}?" \
      "X-Amz-Algorithm=AWS4-HMAC-SHA256&" \
      "X-Amz-Credential=ABC123&" \
      "X-Amz-Date=#{Time.zone.now.strftime('%Y%m%dT%H%M%SZ')}&" \
      "X-Amz-Expires=900&" \
      "X-Amz-SignedHeaders=host&" \
      "X-Amz-Signature=ABC123"
  end

  before do
    allow(LoginGov::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
  end

  describe '#presigned_image_upload_url' do
    before do
      client_stub = Aws::S3::Client.new(region: region, stub_responses: true)
      client_stub.stub_responses(:list_buckets, { buckets: [{ name: bucket }] })
      resource_stub = Aws::S3::Resource.new(client: client_stub)

      allow(helper).to receive(:s3_resource).and_return(resource_stub)
    end

    it 'returns a URL' do
      allow(LoginGov::Hostdata).
        to receive(:env).and_return(env)
      allow(LoginGov::Hostdata::EC2).
        to receive(:load).and_return(OpenStruct.new(account_id: account_id, region: region))

      expect(
        helper.presigned_image_upload_url(
          image_type: image_type,
          transaction_id: session_uuid).to_s,
      ).to match expected_url_regex
    end
  end
end
