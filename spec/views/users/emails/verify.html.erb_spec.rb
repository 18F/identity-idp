require 'rails_helper'

RSpec.describe 'users/emails/verify.html.erb' do
  subject(:rendered) { render }
  let(:email) { 'foo@bar.com' }
  let(:in_select_email_flow) { nil }
  let(:pending_completions_consent) { false }
  # The page is only reachable behind `confirm_two_factor_authenticated`, so the
  # current user is always a fully-registered (confirmed) user.
  let(:user) { create(:user, :fully_registered) }
  before do
    assign(:email, email)
    assign(:in_select_email_flow, in_select_email_flow)
    assign(:pending_completions_consent, pending_completions_consent)
    # Lazily resolved so examples that do not render the load-testing link do not
    # pay for building a user.
    allow(view).to receive(:current_user) { user }
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end

  it 'has a localized header' do
    expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
  end

  it 'contains link to resend confirmation page' do
    expect(rendered).to have_css(
      "form[action='#{add_email_resend_path}'] button",
      text: t('links.resend'),
    )
  end

  it 'contains link to return to account page' do
    expect(rendered).to have_link(
      t('idv.messages.return_to_profile', app_name: APP_NAME),
      href: account_path,
    )
  end

  context 'when enable_load_testing_mode? is true and email address found' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      create(:email_address, :unconfirmed, user:, confirmation_token: 'some_token', email:)

      render
    end

    it 'links to the add-email confirmation route, not the registration one' do
      expect(rendered).to have_link(
        'CONFIRM NOW',
        href: add_email_confirmation_url(confirmation_token: 'some_token'),
        id: 'confirm-now',
      )
    end

    it 'does not link to the registration confirmation route' do
      expect(rendered).to_not have_link(
        'CONFIRM NOW',
        href: sign_up_create_email_confirmation_url(confirmation_token: 'some_token'),
      )
    end
  end

  context 'when another user has an unconfirmed row for the same email address' do
    let(:other_user) { create(:user) }

    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      create(
        :email_address, :unconfirmed, user: other_user, confirmation_token: 'other_token',
                                      email:
      )

      render
    end

    it 'does not leak a confirmation token belonging to another user' do
      expect(rendered).to_not have_link('CONFIRM NOW')
    end
  end

  context 'when in the select email flow with an SP request' do
    let(:in_select_email_flow) { true }

    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      session[:sp] = { request_id: 'sp-request-id' }
      create(:email_address, :unconfirmed, user:, confirmation_token: 'some_token', email:)

      render
    end

    it 'carries the same params the real add-email confirmation email carries' do
      expect(rendered).to have_link(
        'CONFIRM NOW',
        href: add_email_confirmation_url(
          confirmation_token: 'some_token',
          from_select_email_flow: true,
          request_id: 'sp-request-id',
        ),
      )
    end
  end

  context 'when enable_load_testing_mode? is false' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(false)
      create(:email_address, :unconfirmed, user:, confirmation_token: 'some_token', email:)

      render
    end

    it 'does not generate the link' do
      expect(rendered).not_to have_link('CONFIRM NOW')
    end
  end

  context 'when email address not found' do
    before do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)

      render
    end

    it 'does not generate the link' do
      expect(rendered).not_to have_link('CONFIRM NOW')
    end
  end

  context 'when in email select flow' do
    let(:in_select_email_flow) { true }

    it 'maintains email select flow parameter for resend' do
      expect(rendered).to have_css(
        "form[action='#{add_email_resend_path(in_select_email_flow: true)}'] button",
        text: t('links.resend'),
      )
    end

    context 'in sign up completions flow' do
      let(:pending_completions_consent) { true }

      it 'contains a link to return back to sign up select email selection screen' do
        expect(rendered).to have_link(
          t('forms.buttons.back'),
          href: sign_up_select_email_path,
        )
      end
    end

    context 'in connected accounts flow' do
      let(:pending_completions_consent) { false }

      it 'contains a link to return back to connected accounts screen' do
        expect(rendered).to have_link(
          t('forms.buttons.back'),
          href: account_connected_services_path,
        )
      end
    end
  end
end
