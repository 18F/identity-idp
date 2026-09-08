require 'rails_helper'

RSpec.describe 'device_profiling_failed/show.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('profiling_failed.title'))
    render
  end

  it 'renders the heading and exit link' do
    expect(rendered).to have_selector('h1', text: t('profiling_failed.title'))
    expect(rendered).to have_link(t('links.exit_login', app_name: APP_NAME), href: root_url)
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
      expect(rendered).to have_selector('.auth--form-page h1', text: t('profiling_failed.title'))
    end

    it 'renders the error status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the details body copy' do
      expect(rendered).to have_selector('.auth__form-page-body p')
    end

    it 'renders the exit action to the root url' do
      expect(rendered).to have_selector('.auth__actions')
      expect(rendered).to have_link(t('links.exit_login', app_name: APP_NAME), href: root_url)
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
