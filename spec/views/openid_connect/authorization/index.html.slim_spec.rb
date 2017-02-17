require 'rails_helper'

describe 'openid_connect/authorization/index.html.slim' do
  let(:service_provider) { ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test') }

  before do
    @authorize_decorator = OpenidConnectAuthorizeDecorator.new(
      scopes: %w(openid email profile),
      service_provider: service_provider
    )
  end

  it 'renders a list of localized attribute names' do
    render

    %w(email given_name family_name birthdate).each do |attribute|
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
    before { expect(@authorize_decorator).to receive(:logo).and_return(nil) }

    it 'does not render the logo' do
      render

      expect(rendered).to_not have_css('img')
    end
  end
end
