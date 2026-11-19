require 'rails_helper'

RSpec.describe 'idv/enter_dob_ssn/new.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:proofer_mock_fallback) { false }
  let(:threatmetrix_enabled) { false }
  let(:session_id) { 'ABCD-1234' }
  let(:tmx_query) { "org_id=test_org_id&session_id=#{session_id}" }
  let(:tags_js_url) { "https://h.online-metrix.net/fp/tags.js?#{tmx_query}" }
  let(:tags_iframe_url) { "https://h.online-metrix.net/fp/tags?#{tmx_query}" }

  subject(:rendered) do
    render template: 'idv/enter_dob_ssn/new', locals: {
      threatmetrix_session_id: session_id,
      threatmetrix_javascript_urls: [tags_js_url],
      threatmetrix_iframe_url: tags_iframe_url,
    }
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_call_original
    allow(view).to receive(:url_for).with(no_args).and_return(idv_enter_dob_ssn_path)
    allow(view).to receive(:step_indicator_steps)
      .and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
    allow(IdentityConfig.store).to receive(:proofer_mock_fallback)
      .and_return(proofer_mock_fallback)
    allow(FeatureManagement).to receive(:proofing_agent_device_profiling_collecting_enabled?)
      .and_return(threatmetrix_enabled)
    assign(:dob_ssn_form, Idv::DobSsnForm.new(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN))
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('doc_auth.headings.dob_ssn'))

    render template: 'idv/enter_dob_ssn/new', locals: {
      threatmetrix_session_id: nil, threatmetrix_javascript_urls: [], threatmetrix_iframe_url: nil
    }
  end

  context 'in the default layout' do
    it 'renders the heading, SSN and date of birth fields, and the cancel link' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.dob_ssn'))
      expect(rendered).to have_field(t('idv.form.ssn_label'))
      expect(rendered).to have_css('lg-memorable-date')
      expect(rendered).to have_button(t('forms.buttons.continue'))
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'ssn'))
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('doc_auth.headings.dob_ssn'))
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('doc_auth.info.dob_ssn'),
      )
    end

    it 'links to the security and privacy practices in a new tab' do
      expect(rendered).to have_css(
        ".auth__intro-description a[href='#{MarketingSite.security_and_privacy_practices_url}']" \
          "[target='_blank']",
        text: t('doc_auth.info.learn_more'),
      )
    end

    it 'posts the SSN and date of birth to the same path behind the submit gate' do
      expect(rendered).to have_css(
        "form[action='#{idv_enter_dob_ssn_path}'][method='post'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css('.usa-input--ssn .usa-input__control--ssn[name="doc_auth[ssn]"]')
      expect(rendered).to have_css('button.usa-input__toggle[data-nds-ssn-toggle]')
      expect(rendered).to have_css('lg-memorable-date input[name="doc_auth[dob][month]"]')
      expect(rendered).to have_css('lg-memorable-date input[name="doc_auth[dob][day]"]')
      expect(rendered).to have_css('lg-memorable-date input[name="doc_auth[dob][year]"]')
    end

    it 'does not render the ThreatMetrix profiling tags' do
      expect(rendered).to_not have_css("script[src='#{tags_js_url}']", visible: false)
      expect(rendered).to_not have_css("noscript iframe[src='#{tags_iframe_url}']", visible: false)
    end

    context 'with proofing agent device profiling collection enabled' do
      let(:threatmetrix_enabled) { true }

      it 'renders the ThreatMetrix profiling tags' do
        expect(rendered).to have_css("script[nonce][src='#{tags_js_url}']", visible: false)
        expect(rendered).to have_css(
          "noscript iframe[src='#{tags_iframe_url}'][sandbox='']",
          visible: false,
        )
      end
    end

    it 'renders continue and a tertiary cancel action' do
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{idv_cancel_path(step: 'ssn')}']",
        text: t('links.cancel'),
      )
    end

    it 'sets the verification header progress' do
      rendered

      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
        text: '7 / 12',
      )
    end

    it 'does not render the test SSN alert' do
      expect(rendered).to_not have_text(t('doc_auth.instructions.test_ssn'))
    end

    context 'with the mock proofer fallback' do
      let(:proofer_mock_fallback) { true }

      it 'renders the test SSN alert in the card' do
        expect(rendered).to have_selector(
          '.auth--form-page .usa-alert--info',
          text: t('doc_auth.instructions.test_ssn'),
        )
      end
    end

    context 'when the information does not match' do
      before do
        flash.now[:error] = t('idv.failure.dob_ssn.warning')
      end

      it 'renders the error in the card' do
        expect(rendered).to have_selector(
          '.auth--form-page .usa-alert--error',
          text: t('idv.failure.dob_ssn.warning'),
        )
      end
    end
  end
end
