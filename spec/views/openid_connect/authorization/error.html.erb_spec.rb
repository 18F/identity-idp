require 'rails_helper'

RSpec.describe 'openid_connect/authorization/error.html.erb' do
  let(:authorize_form) { OpenidConnectAuthorizeForm.new({}) }
  let(:message) { t('openid_connect.authorization.errors.bad_client_id') }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    authorize_form.errors.add(:client_id, message)
    assign(:authorize_form, authorize_form)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.openid_connect.authorization'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'lists the authorization errors' do
      expect(rendered).to have_css('ul li', text: message)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the error badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('titles.openid_connect.authorization'),
      )
    end

    it 'lists every authorization error after the divider' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body ul.usa-list li', count: 1, text: message)
    end
  end
end
