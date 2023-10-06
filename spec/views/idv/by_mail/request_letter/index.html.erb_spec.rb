require 'rails_helper'

RSpec.describe 'idv/by_mail/request_letter/index.html.erb' do
  let(:resend_requested) { false }
  let(:user_needs_address_otp_verification) { false }
  let(:go_back_path) { nil }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }
  let(:presenter) do
    user = build_stubbed(:user, :fully_registered)
    Idv::ByMail::RequestLetterPresenter.new(user, {})
  end

  let(:address1) { 'applicant address 1' }
  let(:address2) { nil }
  let(:city) { 'applicant city' }
  let(:state) { 'applicant state' }
  let(:zipcode) { 'applicant zipcode' }

  before do
    allow(view).to receive(:go_back_path).and_return(go_back_path)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)

    allow(presenter).to receive(:resend_requested?).and_return(resend_requested)
    allow(presenter).to receive(:user_needs_address_otp_verification?).
      and_return(user_needs_address_otp_verification)

    @presenter = presenter
    @applicant = {
      address1: 'applicant address 1',
      city: 'applicant city',
      state: 'applicant state',
      zipcode: 'applicant zipcode',
    }
    if address2
      @applicant[:address2] = 'applicant address 2'
    end
    render
  end

  it 'prompts to send letter' do
    expect(rendered).to have_content(I18n.t('idv.titles.mail.verify'))
    expect(rendered).to have_button(I18n.t('idv.buttons.mail.send'))
  end

  it 'renders fallback link to return to phone verify path' do
    expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: idv_phone_path)
  end

  context 'has page to go back to' do
    let(:go_back_path) { idv_otp_verification_path }

    it 'renders back link to return to previous path' do
      expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: go_back_path)
    end
  end

  it 'renders the address lines' do
    expect(rendered).to have_content('applicant address 1')
    expect(rendered).to have_content('applicant city, applicant state applicant zipcode')
  end

  context 'when there is an address2' do
    let(:address2) { "applicant address 2" }

    it 'renders the addresss line' do
      expect(rendered).to have_content('applicant address 2')
    end
  end

  context 'letter already sent' do
    let(:resend_requested) { true }

    it 'has the right title' do
      expect(rendered).to have_css('h1', text: t('idv.gpo.request_another_letter.title'))
    end

    it 'has the right body' do
      expect(rendered).to have_text(
        strip_tags(t('idv.gpo.request_another_letter.instructions_html')),
      )
    end

    it 'includes link to help' do
      expect(rendered).to have_link(
        t('idv.gpo.request_another_letter.learn_more_link'),
        href: help_center_redirect_url(
          category: 'verify-your-identity',
          article: 'verify-your-address-by-mail',
          flow: :idv,
          step: :gpo_send_letter,
        ),
      )
    end

    it 'does not include troubleshooting options' do
      expect(rendered).not_to have_css('.troubleshooting-options')
    end
  end

  context 'user needs address otp verification' do
    let(:user_needs_address_otp_verification) { true }

    it 'renders fallback link to return to verify path' do
      expect(rendered).to have_link(
        '‹ ' + t('forms.buttons.back'),
        href: idv_verify_by_mail_enter_code_path,
      )
    end
  end
end
