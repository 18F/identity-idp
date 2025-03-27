require 'rails_helper'

RSpec.describe 'shared/_nav_branded.html.erb' do
  let(:view_context) { ActionController::Base.new.view_context }
  let(:sp_with_logo) do
    build_stubbed(
      :service_provider, logo: 'generic.svg', friendly_name: 'Best SP ever'
    )
  end
  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp_with_logo,
      view_context: view_context,
      sp_session: {},
      service_provider_request: nil,
    )
  end

  context 'with a SP-logo configured' do
    before do
      allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
      allow(view).to receive(:current_sp).and_return(sp_with_logo)
      render
    end

    it 'displays the SP logo' do
      expect(rendered).to have_css("img[alt*='Best SP ever']")
    end
  end

  context 'with a S3 SP-logo configured' do
    let(:sp_with_s3_logo) do
      build_stubbed(
        :service_provider,
        friendly_name: 'Awesome Application!',
        return_to_sp_url: 'www.awesomeness.com',
        remote_logo_key: 'key-to-logo',
      )
    end
    let(:bucket) { 'bucket_id' }
    let(:region) { IdentityConfig.store.aws_region }
    let(:img_url) { "https://s3.#{region}.amazonaws.com/#{bucket}/key-to-logo" }
    let(:decorated_sp_session) do
      ServiceProviderSession.new(
        sp: sp_with_s3_logo,
        view_context: view_context,
        sp_session: {},
        service_provider_request: nil,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:aws_logo_bucket).and_return(bucket)
      allow(FeatureManagement).to receive(:logo_upload_enabled?).and_return(true)
      allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
      allow(view).to receive(:current_sp).and_return(sp_with_s3_logo)

      render
    end

    it 'renders the logo from S3' do
      expect(rendered).to match(/src="#{img_url}"/)
    end
  end

  context 'without a SP-logo configured' do
    let(:sp_without_logo) { build_stubbed(:service_provider, friendly_name: 'No logo no problem') }
    let(:decorated_sp_session) do
      ServiceProviderSession.new(
        sp: sp_without_logo,
        view_context: view_context,
        sp_session: {},
        service_provider_request: nil,
      )
    end

    before do
      allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
      allow(view).to receive(:current_sp).and_return(sp_without_logo)
      render
    end

    it 'displayes the generic SP logo' do
      expect(rendered).to have_css("img[alt*='No logo no problem']")
    end
  end

  context 'service provider has a poorly configured logo' do
    let(:sp) { build_stubbed(:service_provider, logo: 'abc') }
    let(:decorated_sp_session) do
      ServiceProviderSession.new(
        sp:,
        view_context:,
        sp_session: {},
        service_provider_request: nil,
      )
    end
    before do
      allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
      allow(view).to receive(:current_sp).and_return(sp)
    end

    it 'does not raise an exception' do
      expect { render }.not_to raise_exception
    end
  end
end
