require 'rails_helper'

RSpec.describe 'users/emails/show.html.erb' do
  let(:form) { AddUserEmailForm.new }
  let(:pending_completions_consent) { false }
  let(:cancel_link_url) { account_path }
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:decorated_sp_session)
      .and_return(instance_double(ServiceProviderSession, cancel_link_url:))
    assign(:add_user_email_form, form)
    assign(:pending_completions_consent, pending_completions_consent)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.add_email'))

    render
  end

  it 'renders the legacy add email form' do
    render

    expect(rendered).to have_css('h1', text: t('headings.add_email'))
    expect(rendered).to have_css("form[action='#{add_email_path}'] input[name='user[email]']")
    expect(rendered).to have_link(t('notices.privacy.privacy_act_statement'))
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the heading and the email field in the signed-in header layout' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
      expect(rendered).to have_css('.auth--form-page h1', text: t('headings.add_email'))
      expect(rendered).to have_css(
        "form[action='#{add_email_path}'][method=post][data-nds-submit-gate] " \
          "input[type=email][name='user[email]'][required][autocomplete=email]",
      )
      expect(rendered).to have_css('label', text: t('account.index.email_short'))
      expect(rendered).to_not have_link(t('notices.privacy.privacy_act_statement'))
    end

    it 'renders a primary Continue submit above a tertiary Cancel' do
      render

      expect(rendered).to have_css(
        '.auth__actions button[type=submit].usa-button:not(.usa-button--secondary)',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: cancel_link_url,
        class: 'usa-button--tertiary',
      )
    end

    context 'with an email error' do
      let(:form) do
        AddUserEmailForm.new.tap do |f|
          f.errors.add(:email, t('valid_email.validations.email.invalid'))
        end
      end

      it 'ties the error to the email field' do
        render

        expect(rendered).to have_css('input[type=email][aria-invalid=true]')
        expect(rendered).to have_content(t('valid_email.validations.email.invalid'))
      end
    end

    context 'with a pending completions consent' do
      let(:pending_completions_consent) { true }

      it 'goes back to the consent page in place of Cancel' do
        render

        expect(rendered).to have_link(
          t('forms.buttons.back'),
          href: sign_up_completed_url,
          class: 'usa-button--tertiary',
        )
        expect(rendered).to_not have_link(t('links.cancel'))
      end
    end
  end
end
