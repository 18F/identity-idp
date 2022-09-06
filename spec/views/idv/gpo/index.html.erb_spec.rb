require 'rails_helper'

describe 'idv/gpo/index.html.erb' do
  let(:letter_already_sent) { false }
  let(:user_needs_address_otp_verification) { false }
  let(:go_back_path) { nil }
  let(:step_indicator_steps) { Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS }
  let(:presenter) do
    user = build_stubbed(:user, :signed_up)
    Idv::GpoPresenter.new(user, {})
  end

  before do
    allow(view).to receive(:go_back_path).and_return(go_back_path)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)

    allow(presenter).to receive(:letter_already_sent?).and_return(letter_already_sent)
    allow(presenter).to receive(:user_needs_address_otp_verification?).
      and_return(user_needs_address_otp_verification)

    @presenter = presenter
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

  context 'letter already sent' do
    let(:letter_already_sent) { true }

    it 'prompts to send another letter' do
      expect(rendered).to have_content(I18n.t('idv.titles.mail.resend'))
      expect(rendered).to have_button(I18n.t('idv.buttons.mail.resend'))
    end
  end

  context 'user needs address otp verification' do
    let(:user_needs_address_otp_verification) { true }

    it 'renders fallback link to return to verify path' do
      expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: idv_gpo_verify_path)
    end
  end
end
