require 'rails_helper'

RSpec.describe ImageUploadPresignedUrlGenerator do
  include Rails.application.routes.url_helpers

  subject(:generator) { ImageUploadPresignedUrlGenerator.new }

  describe '#presigned_image_upload_url' do
    subject(:presigned_image_upload_url) do
      generator.presigned_image_upload_url(image_type: image_type, transaction_id: transaction_id)
    end

    let(:image_type) { 'front' }
    let(:transaction_id) { SecureRandom.uuid }

    before do
      expect(Figaro.env).
        to receive(:doc_auth_enable_presigned_s3_urls).and_return(doc_auth_enable_presigned_s3_urls)
    end

    context 'when doc_auth_enable_presigned_s3_urls is disabled' do
      let(:doc_auth_enable_presigned_s3_urls) { 'false' }

      it 'is nil' do
        expect(presigned_image_upload_url).to eq(nil)
      end
    end

    context 'when doc_auth_enable_presigned_s3_urls is enabled' do
      let(:doc_auth_enable_presigned_s3_urls) { 'true' }

      before do
        expect(LoginGov::Hostdata).to receive(:in_datacenter?).and_return(in_datacenter)
      end

      context 'when run locally' do
        let(:in_datacenter) { false }

        it 'is a local fake S3 URL' do
          expect(presigned_image_upload_url).
            to eq(test_fake_s3_url(key: "#{transaction_id}-#{image_type}"))
        end
      end

      context 'when run in the datacenter' do
        let(:in_datacenter) { true }

        let(:real_s3_url) { 'https://s3.example.com/key/id/1234' }

        it 'is a real S3 url' do
          # from aws_s3_helper
          expect(generator).to receive(:s3_presigned_url).
            with(hash_including(keyname: "#{transaction_id}-#{image_type}")).
            and_return(real_s3_url)

          expect(presigned_image_upload_url).to eq(real_s3_url)
        end
      end
    end
  end

  describe '#bucket_url' do
    before do
      allow(LoginGov::Hostdata).to receive(:env).and_return('test')
      allow(LoginGov::Hostdata::EC2).to receive(:load).and_return(
        OpenStruct.new(account_id: '123456789', region: 'us-west-2'),
      )
      client_stub = Aws::S3::Client.new(region: 'us-west-2', stub_responses: true)
      resource_stub = Aws::S3::Resource.new(client: client_stub)
      allow(generator).to receive(:s3_resource).and_return(resource_stub)
    end

    it 'is S3 bucket url' do
      expect(generator.bucket_url).to eq(
        'https://s3.us-west-2.amazonaws.com/login-gov-idp-doc-capture-test.123456789-us-west-2',
      )
    end
  end
end
