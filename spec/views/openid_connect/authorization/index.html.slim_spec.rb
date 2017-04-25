require 'rails_helper'

describe 'openid_connect/authorization/index.html.slim' do
  let(:view_context) { ActionController::Base.new.view_context }

  before do
    @authorize_decorator = OpenidConnectAuthorizeDecorator.new(
      scopes: %w[openid email profile]
    )
    sp = build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      logo: 'generic.svg'
    )
    decorated_session = DecoratedSession.new(
      sp: sp, view_context: view_context, sp_session: {}
    ).call
    allow(view).to receive(:decorated_session).and_return(decorated_session)
  end

  it 'renders a list of localized attribute names' do
    render

    %w[email given_name family_name birthdate].each do |attribute|
      translated_attribute = I18n.t("openid_connect.authorization.index.attributes.#{attribute}")
      expect(rendered).to have_xpath("//li[text()='#{translated_attribute}']")
    end
  end

  context 'when the service provider has a logo' do
    it 'renders the logo' do
      render

      expect(rendered).to have_css('img[src*=sp-logos]')
    end
  end

  context 'when the service provider does not have a logo' do
    it 'renders the default logo' do
      sp_without_logo = build_stubbed(:service_provider)
      decorated_session = ServiceProviderSessionDecorator.new(
        sp: sp_without_logo, view_context: view_context, sp_session: {}
      )
      allow(view).to receive(:decorated_session).and_return(decorated_session)
      render

      expect(rendered).to have_css('img[src*=sp-logos]')
    end
  end
end
