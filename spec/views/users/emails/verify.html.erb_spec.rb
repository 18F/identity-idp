require 'rails_helper'

RSpec.describe 'users/emails/verify.html.erb' do
  let(:email) { 'foo@bar.com' }
  before do
    allow(view).to receive(:email).and_return(email)
    @resend_email_confirmation_form = ResendEmailConfirmationForm.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
  end

  it 'contains link to resend confirmation page' do
    render

    expect(rendered).to have_button(t('links.resend'))
  end

  context 'when enable_load_testing_mode? is true and email address found' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      create(:email_address, confirmation_token: 'some_token', email:)

      render
    end

    it 'generates the correct link' do
      expect(rendered).to have_link(
        'CONFIRM NOW',
        href: sign_up_create_email_confirmation_url(confirmation_token: 'some_token'),
        id: 'confirm-now',
      )
    end
  end

  context 'when enable_load_testing_mode? is false' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(false)

      render
    end

    it 'does not generate the link' do
      expect(rendered).not_to have_link('CONFIRM NOW', href: sign_up_create_email_confirmation_url)
    end
  end

  context 'when email address not found' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)

      render
    end

    it 'does not generate the link' do
      expect(rendered).not_to have_link('CONFIRM NOW', href: sign_up_create_email_confirmation_url)
    end
  end
end
