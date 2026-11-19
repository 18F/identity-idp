require 'rails_helper'

RSpec.describe 'devise/sessions/bounced.html.erb' do
  let(:sp_name) { 'Test Service Provider' }
  let(:sp_link) { 'https://sp.example.com' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:sp_name, sp_name)
    assign(:sp_link, sp_link)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('headings.sp_handoff_bounced', sp_name:))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the heading, the instructions and the sign in button' do
      expect(rendered).to have_css('h1', text: t('headings.sp_handoff_bounced', sp_name:))
      expect(rendered).to have_content(sp_name)
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.back_to_sign_in'),
        href: root_url,
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the error badge and heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('headings.sp_handoff_bounced', sp_name:),
      )
    end

    it 'renders the instructions with a link to the service provider' do
      render

      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(".auth__form-page-body p a[href='#{sp_link}']", text: sp_name)
    end

    it 'renders a primary action back to sign in' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{root_url}']",
        text: t('instructions.mfa.piv_cac.back_to_sign_in'),
      )
    end

    context 'without a service provider link' do
      let(:sp_name) { t('instructions.sp_handoff_bounced_with_no_sp') }
      let(:sp_link) { nil }

      it 'names the service provider without a link' do
        render

        expect(rendered).to have_css('.auth__form-page-body p', text: sp_name)
        expect(rendered).not_to have_css('.auth__form-page-body p a')
      end
    end

    context 'with markup in the service provider name' do
      let(:sp_name) { '<b>Agency</b>' }

      it 'escapes the service provider name' do
        render

        expect(rendered).not_to have_css('.auth__form-page-body b')
        expect(rendered).to have_css('.auth__form-page-body p a', text: sp_name)
      end
    end
  end
end
