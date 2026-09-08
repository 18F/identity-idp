require 'rails_helper'

RSpec.describe 'idv/unavailable/show.html.erb' do
  let(:sp_name) { nil }
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:decorated_sp_session).and_return(
      instance_double(ServiceProviderSession, sp_name: sp_name),
    )
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('idv.titles.unavailable'))
    render
  end
  it 'has an h1' do
    expect(rendered).to have_selector('h1', text: t('idv.titles.unavailable'))
  end
  it 'links to the status page in a new window' do
    expect(rendered).to have_selector(
      'a[target=_blank]',
      text: t('idv.unavailable.status_page_link'),
    )
  end

  describe('exit button') do
    it 'is rendered' do
      expect(rendered).to have_selector(
        'a',
        text: t('idv.unavailable.exit_button', app_name: APP_NAME),
      )
    end
    it 'links to the right place' do
      expect(rendered).to have_link(
        t('idv.unavailable.exit_button', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path(step: 'unavailable', location: 'unavailable'),
      )
    end
  end

  it 'does not render any l13n markers' do
    expect(rendered).not_to include('%{')
  end

  context 'with sp' do
    let(:sp_name) { 'Department of Ice Cream' }
    it 'renders the explanation with the sp name' do
      expect(rendered).to include(sp_name)
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the unavailable heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('idv.titles.unavailable'))
    end

    it 'renders the error status-icon badge above the heading' do
      render

      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider under the heading' do
      render

      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the technical-difficulties and next-steps body copy' do
      render

      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('idv.unavailable.technical_difficulties'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body a[target=_blank]',
        text: t('idv.unavailable.status_page_link'),
      )
    end

    it 'renders the exit action button to the failure-to-proof path' do
      render

      expect(rendered).to have_selector('.auth__actions')
      expect(rendered).to have_link(
        t('idv.unavailable.exit_button', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path(step: 'unavailable', location: 'unavailable'),
      )
    end

    it 'renders the without-sp explanation by default' do
      render

      expect(rendered).to have_content(t('idv.unavailable.idv_explanation.without_sp'))
    end

    it 'does not render any l13n markers' do
      render

      expect(rendered).not_to include('%{')
    end

    context 'with sp' do
      let(:sp_name) { 'Department of Ice Cream' }

      it 'renders the explanation with the sp name' do
        render

        expect(rendered).to include(sp_name)
      end
    end
  end
end
