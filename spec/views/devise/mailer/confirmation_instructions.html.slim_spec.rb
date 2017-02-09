require 'rails_helper'

describe 'devise/mailer/confirmation_instructions.html.slim' do
  it 'mentions how long the user has to confirm' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    assign(:resource, user)
    assign(:confirmation_period, user.decorate.confirmation_period)
    render

    expect(rendered).to have_content(
      t(
        'mailer.confirmation_instructions.footer',
        confirmation_period: user.decorate.confirmation_period
      )
    )
  end

  it 'includes a link to confirmation' do
    assign(:resource, build_stubbed(:user, confirmed_at: Time.zone.now))
    assign(:token, 'foo')
    render

    expect(rendered).to have_link(
      'http://test.host/sign_up/email/confirm?confirmation_token=foo',
      href: 'http://test.host/sign_up/email/confirm?confirmation_token=foo'
    )
  end

  it 'mentions updating an account when user has already been confirmed' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:resource, user)
    assign(:first_sentence, presenter.first_sentence)
    render

    expect(rendered).to have_content(
      I18n.t(
        'mailer.confirmation_instructions.first_sentence.confirmed',
        app: APP_NAME, confirmation_period: presenter.confirmation_period
      )
    )

    expect(rendered).to have_xpath("//p[contains(@class, 'lead')]/a[text()='#{APP_NAME}']")
  end

  it 'mentions creating an account when user is not yet confirmed' do
    user = build_stubbed(:user, confirmed_at: nil)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:resource, user)
    assign(:first_sentence, presenter.first_sentence)
    render

    expect(rendered).to have_content(
      I18n.t(
        'mailer.confirmation_instructions.first_sentence.unconfirmed',
        app: APP_NAME, confirmation_period: presenter.confirmation_period
      )
    )

    expect(rendered).to have_xpath("//p[contains(@class, 'lead')]/a[text()='#{APP_NAME}']")
  end

  it 'mentions resetting the account when account has been reset by tech support' do
    user = build_stubbed(:user, reset_requested_at: Time.zone.now)
    presenter = ConfirmationEmailPresenter.new(user, self)
    assign(:resource, user)
    assign(:first_sentence, presenter.first_sentence)
    render

    expect(rendered).to have_content(
      I18n.t(
        'mailer.confirmation_instructions.first_sentence.reset_requested',
        app: APP_NAME
      )
    )

    expect(rendered).to have_xpath("//p[contains(@class, 'lead')]/a[text()='#{APP_NAME}']")
  end
end
