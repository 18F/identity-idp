require 'rails_helper'

RSpec.describe 'destructive_account_reset/confirm_request/show.html.erb' do
  let(:email) { 'foo@bar.com' }
  let(:sms_phone) { true }
  let(:waiting_period) { '24 hours' }

  before do
    allow(view).to receive(:email).and_return(email)
    allow(view).to receive(:sms_phone).and_return(sms_phone)
    allow(view).to receive(:waiting_period).and_return(waiting_period)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end

  it 'does not render the NDS form-page card' do
    render
    expect(rendered).not_to have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:second_email_note) do
      t('destructive_account_reset.confirm_request.info_html', email:, waiting_period:)[1]
    end
    let(:cancel_note) do
      t('destructive_account_reset.confirm_request.info_html', email:, waiting_period:)[2]
    end

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the check your email heading with the email address' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: t('headings.verify_email'))
      expect(rendered).to have_css('.auth__intro-description strong', text: email)
    end

    it 'renders the heads up card with the waiting period and cancel notes' do
      render

      expect(rendered).to have_css(
        '.card h2',
        text: t('nds.destructive_account_reset.confirm_request.heads_up'),
      )
      expect(rendered).to have_css('.card p', text: second_email_note)
      expect(rendered).to have_css('.card p', text: cancel_note)
      expect(rendered).to have_content(waiting_period)
    end

    it 'does not link the cancel note, since cancelling requires the emailed token' do
      render

      expect(rendered).not_to have_css('.card a')
    end

    it 'renders the SMS security note' do
      render

      expect(rendered).to have_css(
        '.card p',
        text: t('destructive_account_reset.confirm_request.security_note'),
      )
    end

    context 'without a phone configured' do
      let(:sms_phone) { false }

      it 'omits the SMS security note' do
        render

        expect(rendered).not_to have_content(
          t('destructive_account_reset.confirm_request.security_note'),
        )
      end
    end
  end
end
