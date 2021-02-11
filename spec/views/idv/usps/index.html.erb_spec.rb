require 'rails_helper'

describe 'idv/usps/index.html.erb' do
  let(:usps_mail_bounced) { false }
  let(:letter_already_sent) { false }
  let(:user_needs_address_otp_verification) { false }
  let(:presenter) do
    user = build_stubbed(:user, :signed_up)
    Idv::UspsPresenter.new(user, {})
  end

  before do
    allow(presenter).to receive(:usps_mail_bounced?).and_return(usps_mail_bounced)
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

  it 'renders link to return to phone verify path' do
    expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: idv_phone_path)
  end

  context 'usps mail bounced' do
    let(:usps_mail_bounced) { true }

    it 'renders address form to resend letter' do
      expect(rendered).to have_content(I18n.t('idv.messages.usps.new_address'))
      expect(rendered).to have_field(t('idv.form.address1'))
      expect(rendered).to have_button(I18n.t('idv.buttons.mail.resend'))
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

    it 'renders link to return to verify path' do
      expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: verify_account_path)
    end
  end
end
