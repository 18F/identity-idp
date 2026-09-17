require 'rails_helper'

RSpec.describe 'sign_up/emails/show.html.erb' do
  let(:email) { 'foo@bar.com' }
  before do
    allow(view).to receive(:email).and_return(email)
    allow(view).to receive(:nds_layout?).and_return(false)
    @resend_email_confirmation_form = ResendEmailConfirmationForm.new(email:)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the check-your-email heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('headings.verify_email'))
    end

    it 'sets the account-creation header progress at the Account 1/2 substep' do
      render

      progress = view.content_for(:nds_header_progress)
      expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
      expect(progress).to have_css('.progress__step-counter', text: '1 / 2')
    end

    it 'renders the body copy including the email address' do
      render

      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: "We sent a link to #{email}",
      )
      expect(rendered).to have_selector('.auth__intro-description strong', text: email)
    end

    it 'renders the resend confirmation submit button posting to the register path' do
      render

      expect(rendered).to have_css("form[action='#{sign_up_register_path}']")
      expect(rendered).to have_field('user[email]', type: :hidden, with: email)
      expect(rendered)
        .to have_button(t('notices.verify_email.resend'))
    end

    it 'renders the use-a-different-email link to the email entry path' do
      render

      expect(rendered).to have_link(
        t('notices.verify_email.use_different_email'),
        href: sign_up_email_path,
      )
    end

    it 'does not render the success alert without a resend confirmation' do
      render

      expect(rendered).to_not have_content(t('notices.resend_confirmation_email.success'))
    end

    context 'when a confirmation email was just resent' do
      before { @resend_confirmation = true }

      it 'renders the success alert inside the card' do
        render

        expect(rendered).to have_content(t('notices.resend_confirmation_email.success'))
      end
    end
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
