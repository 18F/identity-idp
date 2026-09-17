require 'rails_helper'

RSpec.describe 'banned_user/show.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('banned_user.title'))
    render
  end

  it 'renders the heading and details' do
    expect(rendered).to have_selector('h1', text: t('banned_user.title'))
    expect(rendered).to have_content(t('banned_user.details'))
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
      expect(rendered).to have_selector('.auth--form-page h1', text: t('banned_user.title'))
    end

    it 'renders the error status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the details body copy' do
      expect(rendered).to have_selector('.auth__form-page-body', text: t('banned_user.details'))
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
