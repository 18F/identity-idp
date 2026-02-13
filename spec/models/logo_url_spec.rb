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

  context 'when the logo upload feature is enabled' do
    let(:aws_region) { 'us-west-2' }
    let(:aws_logo_bucket) { 'logo-bucket' }
    let(:remote_logo_key) { 'llave' }
    before do
      allow(FeatureManagement).to receive(:logo_upload_enabled?).and_return(true)
      allow(IdentityConfig.store).to receive(:aws_logo_bucket)
        .and_return(aws_logo_bucket)
    end

    context 'when the remote logo key is present' do
      let(:sp) { ServiceProvider.new(logo: logo, remote_logo_key: remote_logo_key) }

      it 'uses the s3_logo_url' do
        expect(subject.url).to match("https://s3.#{aws_region}.amazonaws.com/#{aws_logo_bucket}/#{remote_logo_key}")
      end
    end
  end
end
