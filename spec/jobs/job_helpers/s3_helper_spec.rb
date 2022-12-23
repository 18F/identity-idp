require 'rails_helper'

RSpec.describe JobHelpers::S3Helper do
  subject(:s3_helper) { JobHelpers::S3Helper.new }

  describe '#s3_url?' do
    subject(:s3_url?) { s3_helper.s3_url?(url) }

    context 'with a subdomain bucket format url' do
      let(:url) { 'https://s3.region-name.amazonaws.com/bucket/key' }
      it { is_expected.to eq(true) }
    end

    context 'with a path bucket format url' do
      let(:url) { 'https://bucket.s3.region-name.amazonaws.com/key' }
      it { is_expected.to eq(true) }
    end

    context 'with a non-s3 url' do
      let(:url) { 'https://example.com' }
      it { is_expected.to eq(false) }
    end

    context 'with a non-s3 url that has an s3 subdomain' do
      let(:url) { 'https://s3.example.com' }
      it 'gets fooled and returns true' do
        expect(s3_url?).to eq(true)
      end
    end
  end

  describe '#download' do
    let(:bucket_name) { 'bucket123456' }
    let(:prefix) { SecureRandom.uuid }
    let(:body) { SecureRandom.random_bytes(128) }

    before do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: lambda do |context|
            expect(context.params[:key]).to eq(prefix)
            expect(context.params[:bucket]).to eq(bucket_name)

            { body: body }
          end,
        },
      }
    end

    context 'with subdomain bucket format' do
      let(:url) do
        "https://s3.region-name.amazonaws.com/#{bucket_name}/#{prefix}?param=true&signature=123"
      end

      it 'downloads by extracting prefix and bucket from s3 URLs' do
        expect(s3_helper.download(url)).to eq(body)
      end
    end

    context 'with path bucket format' do
      let(:url) do
        "https://#{bucket_name}.s3.region-name.amazonaws.com/#{prefix}?param=true&signature=123"
      end

      it 'downloads by extracting prefix and bucket from s3 URLs' do
        expect(s3_helper.download(url)).to eq(body)
      end
    end

    let(:url) do
      "https://s3.region-name.amazonaws.com/#{bucket_name}/#{prefix}?param=true&signature=123"
    end

    it 'returns binary-encoded string bodies' do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: {
            body: body,
          },
        },
      }

      expect(s3_helper.download(url).encoding.name).to eq('ASCII-8BIT')
    end
  end

  let(:valid_bucket_name) { 'valid-attempts-api-s3-bucket' }

  describe '#attempts_bucket_methods' do
    subject(:attempts_s3_write_enabled) { s3_helper.attempts_s3_write_enabled }

    context 'with no bucket name' do
      it 'should return nil' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).and_return(nil)
        is_expected.to eq(nil)
      end
    end

    context 'with a default bucket name' do
      it 'should return false' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return('default-placeholder')
        is_expected.to eq(false)
      end
    end

    context 'with a valid bucket name' do
      it 'should return true' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return(valid_bucket_name)
        is_expected.to eq(true)
      end
    end
  end

  describe '#attempts_s3_serve_enabled' do
    subject(:attempts_s3_serve_enabled) { s3_helper.attempts_s3_serve_enabled }

    context 'with s3 disabled and a valid s3 bucket' do
      it 'should return false' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(false)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return(valid_bucket_name)
        is_expected.to eq(false)
      end
    end

    context 'with s3 disabled and no s3 bucket' do
      it 'should return false' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(false)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).and_return(nil)
        is_expected.to eq(false)
      end
    end

    context 'with s3 enabled and a valid s3 bucket' do
      it 'should return true' do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return('valid-attempts-api-s3-bucket')
        is_expected.to eq(true)
      end
    end
  end
end
