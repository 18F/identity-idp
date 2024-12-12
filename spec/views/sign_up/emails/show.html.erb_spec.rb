require 'rails_helper'

RSpec.describe 'sign_up/emails/show.html.erb' do
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

  it 'contains a form link to resend confirmation page' do
    render

    expect(rendered).to have_selector('lg-form-link')
    expect(rendered).to have_link(href: '#', class: ['usa-link', 'block-link'])
    expect(rendered)
      .to have_button(t('notices.signed_up_but_unconfirmed.resend_confirmation_email'))
    expect(rendered).to have_css("form[action='#{sign_up_register_path}']")
  end

  context 'when enable_load_testing_mode? is true and email address found' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      create(:email_address, confirmation_token: 'some_token', email: email)

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
