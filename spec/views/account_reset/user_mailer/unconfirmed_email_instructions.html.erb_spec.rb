require 'rails_helper'

describe 'user_mailer/unconfirmed_email_instructions.html.erb' do
  it 'states that the email is not associated with a user account' do
    user = build_stubbed(:user, confirmed_at: nil)
    assign(:resource, user)
    assign(:confirmation_period, user.decorate.confirmation_period)
    render

    expect(rendered).to have_content(
      t(
        'user_mailer.email_confirmation_instructions.request_with_diff_email',
        app_name: APP_NAME || 'login.gov',
      ),
    )

    expect(rendered).to have_content(
      t(
        'user_mailer.email_confirmation_instructions.footer',
        confirmation_period: user.decorate.confirmation_period,
      ),
    )
  end

  it 'mentions how long the user has to confirm' do
    user = build_stubbed(:user, confirmed_at: nil)
    assign(:resource, user)
    assign(:confirmation_period, user.decorate.confirmation_period)
    render

    expect(rendered).to have_content(
      t(
        'user_mailer.email_confirmation_instructions.footer',
        confirmation_period: user.decorate.confirmation_period,
      ),
    )
  end

  it 'includes a link to confirmation' do
    assign(:resource, build_stubbed(:user, confirmed_at: nil))
    assign(:token, 'foo')
    render

    expect(rendered).to have_link(
      t('user_mailer.email_confirmation_instructions.create_new_account'),
      href: 'http://test.host/sign_up/email/confirm?confirmation_token=foo',
    )
  end

  context 'in a non-default locale' do
    before { assign(:locale, 'fr') }

    it 'puts the locale in the URL' do
      assign(:resource, build_stubbed(:user, confirmed_at: nil))
      assign(:token, 'foo')
      render

      expect(rendered).to have_link(
        t('user_mailer.email_confirmation_instructions.create_new_account'),
        href: 'http://test.host/fr/sign_up/email/confirm?confirmation_token=foo',
      )
    end
  end
end
