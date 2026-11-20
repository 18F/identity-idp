require 'rails_helper'

RSpec.describe 'idv/phone_errors/jobfail.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:gpo_letter_available) { false }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    assign(:gpo_letter_available, gpo_letter_available)

    render
  end

  it 'shows warning text' do
    expect(rendered).to have_text(t('idv.failure.phone.jobfail'))
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_phone_path)
  end

  it 'shows contact support option' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: contact_redirect_url,
    )
  end

  context 'gpo verification disabled' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).not_to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_request_letter_path,
      )
    end
  end

  context 'gpo verification enabled' do
    let(:gpo_letter_available) { true }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_request_letter_path,
      )
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the warning status page with the heading and copy' do
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth--form-page h1', text: t('idv.failure.phone.heading'))
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted p',
        text: t('idv.failure.phone.jobfail'),
      )
    end

    it 'sets the verification header progress to the phone substep' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        '.progress__step[aria-current="step"] .progress__step-counter',
        text: '8 / 12',
      )
    end

    it 'renders a primary try again link to the phone step' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button:not(.usa-button--secondary):not(.usa-button--tertiary)" \
        "[href='#{idv_phone_path}']",
        text: t('idv.failure.button.warning'),
      )
    end

    it 'renders contact support as a tertiary new-tab option with no heading' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[target=_blank][href='#{contact_redirect_url}']",
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
      expect(rendered).to_not have_css('.nds-troubleshooting-options h2')
      expect(rendered).to_not have_link(t('idv.troubleshooting.options.learn_more_verify_by_phone'))
    end

    it 'does not offer verify by mail' do
      expect(rendered).to_not have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end

    context 'when verify by mail is available' do
      let(:gpo_letter_available) { true }

      it 'offers verify by mail as a tertiary option before contact support' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button--tertiary[href='#{idv_request_letter_path}']",
          text: t('idv.troubleshooting.options.verify_by_mail'),
        )
        expect(rendered.index(t('idv.troubleshooting.options.verify_by_mail')))
          .to be < rendered.index(contact_redirect_url)
      end
    end
  end
end
