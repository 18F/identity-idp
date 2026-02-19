require 'rails_helper'

RSpec.describe LogoUrl do
  let(:logo) { '18f.svg' }
  let(:sp) { ServiceProvider.new(logo: logo) }
  subject { described_class.new(sp.logo, sp.remote_logo_key) }

  context 'service provider has a logo' do
    it 'returns the logo' do
      expect(subject.url).to match(%r{sp-logos/18f-[0-9a-f]+\.svg$})
    end
  end

  context 'service provider does not have a logo' do
    let(:logo) { nil }
    it 'returns the default logo' do
      expect(subject.url).to match(%r{/sp-logos/generic-.+\.svg})
    end
  end

  context 'service provider has a poorly configured logo' do
    let(:logo) { 'abc' }
    it 'does not raise an exception' do
      expect(subject.url).to be_kind_of(String)
    end
  end

  context 'when logos uploads are enabled to an S3 bucket' do
    let(:aws_region) { 'us-west-2' }
    let(:aws_logo_bucket) { 'logo-bucket' }
    let(:remote_logo_key) { "llave#{rand(1..1000)}" }
    let(:s3_double) { instance_double(ActiveStorage::Service::S3Service) }
    let(:stubbed_bucket) do
      Aws::S3::Bucket.new(
        name: IdentityConfig.store.aws_logo_bucket, stub_responses: true,
      )
    end

    before do
      allow(FeatureManagement).to receive(:logo_upload_enabled?).and_return(true)
      allow(IdentityConfig.store).to receive(:aws_logo_bucket)
        .and_return(aws_logo_bucket)
      allow(ActiveStorage::Service::S3Service).to receive(:new).and_return(s3_double)
      allow(s3_double).to receive(:bucket).and_return(stubbed_bucket)
    end

    context 'with a remote_logo_key' do
      let(:sp) { ServiceProvider.new(logo: logo, remote_logo_key: remote_logo_key) }

      it 'can return an AWS URL' do
        expect(subject.url).to start_with("https://#{aws_logo_bucket}.s3.#{aws_region}.amazonaws.com/#{remote_logo_key}")
      end

      it 'passes the correct info to and from AWS' do
        expected_url = "https://fake.random.url.gov/#{remote_logo_key}#{rand(1..1000)}"
        stubbed_object = instance_double(Aws::S3::Object)
        allow(stubbed_bucket).to receive(:object).with(remote_logo_key).and_return(stubbed_object)
        expect(stubbed_object).to receive(:presigned_url).with(
          :get,
          expires_in: described_class::LINK_EXPIRY.to_i,
          response_content_disposition: "inline; filename=\"#{logo}\"; filename*=UTF-8''#{logo}",
          response_content_type: 'image/svg+xml',
        ).and_return(expected_url)

        expect(subject.url).to eq(expected_url)
      end
    end

    context 'without a remote_logo_key' do
      let(:sp) { ServiceProvider.new(logo: logo, remote_logo_key: nil) }

      it 'does not contact AWS' do
        allow(s3_double).to receive(:bucket).never
        expected_path = ActionController::Base.helpers.image_path("sp-logos/#{logo}")
        expect(subject.url).to eq(expected_path)
      end
    end

    context 'with no logo filename' do
      let(:sp) { ServiceProvider.new(logo: nil, remote_logo_key: remote_logo_key) }

      it 'falls back to the default logo' do
        expect(subject.url).to match(%r{/sp-logos/generic-.+\.svg})
      end

      it 'does not contact AWS' do
        allow(s3_double).to receive(:bucket).never
        expect(subject.url).to_not include(remote_logo_key)
      end
    end
  end
end
