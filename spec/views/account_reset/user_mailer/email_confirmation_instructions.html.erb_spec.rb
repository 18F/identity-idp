require 'rails_helper'

describe 'user_mailer/email_confirmation_instructions.html.erb' do
  it 'mentions how long the user has to confirm' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    assign(:resource, user)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:confirmation_period, presenter.confirmation_period)
    render

    expect(rendered).to have_content(
      t(
        'user_mailer.email_confirmation_instructions.footer',
        confirmation_period: presenter.confirmation_period,
      ),
    )
  end

  it 'includes a link to confirmation' do
    assign(:resource, build_stubbed(:user, confirmed_at: Time.zone.now))
    assign(:token, 'foo')
    render

    expect(rendered).to have_link(
      'http://test.host/sign_up/email/confirm?confirmation_token=foo',
      href: 'http://test.host/sign_up/email/confirm?confirmation_token=foo',
    )
  end

  context 'in a non-default locale' do
    before { assign(:locale, 'fr') }

    it 'puts the locale in the URL' do
      assign(:resource, build_stubbed(:user, confirmed_at: Time.zone.now))
      assign(:token, 'foo')
      render

      expect(rendered).to have_link(
        'http://test.host/fr/sign_up/email/confirm?confirmation_token=foo',
        href: 'http://test.host/fr/sign_up/email/confirm?confirmation_token=foo',
      )
    end
  end

  it 'mentions updating an account when user has already been confirmed' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:resource, user)
    assign(:first_sentence, presenter.first_sentence)
    render

    expect(rendered).to have_content(
      I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.confirmed',
        app_name: APP_NAME,
        confirmation_period: presenter.confirmation_period,
      ),
    )
  end

  it 'mentions creating an account when user is not yet confirmed' do
    user = build_stubbed(:user, confirmed_at: nil)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:resource, user)
    assign(:first_sentence, presenter.first_sentence)
    render

    expect(rendered).to have_content(
      I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.unconfirmed',
        app_name: APP_NAME,
        confirmation_period: presenter.confirmation_period,
      ),
    )
  end
end
