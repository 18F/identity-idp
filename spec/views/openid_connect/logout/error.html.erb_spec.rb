require 'rails_helper'

RSpec.describe 'openid_connect/logout/error.html.erb' do
  let(:logout_form) do
    OpenidConnectLogoutForm.new(params: {}, current_user: nil).tap(&:valid?)
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:logout_form, logout_form)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('titles.openid_connect.logout'))
    render
  end

  it 'renders the error messages' do
    expect(logout_form.errors.full_messages).to be_present
    logout_form.errors.full_messages.each do |message|
      expect(rendered).to have_selector('li', text: message)
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('titles.openid_connect.logout'),
      )
    end

    it 'renders the error status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider and each error message in a list' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
      expect(rendered).to have_selector(
        '.auth__form-page-body ul.usa-list.text-left li',
        count: logout_form.errors.full_messages.count,
      )
      logout_form.errors.full_messages.each do |message|
        expect(rendered).to have_selector('.auth__form-page-body li', text: message)
      end
    end

    it 'does not render any actions' do
      expect(rendered).to_not have_selector('.auth__actions')
    end
  end
end
