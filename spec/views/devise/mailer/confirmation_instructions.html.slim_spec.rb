require 'rails_helper'

describe 'devise/mailer/confirmation_instructions.html.slim' do
  it 'mentions how long the user has to confirm' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    assign(:resource, user)
    assign(:confirmation_period, user.decorate.confirmation_period)
    render

    expect(rendered).to have_content 'Please note that this confirmation link expires in 24 hours'
  end

  it 'includes a link to confirmation' do
    assign(:resource, build_stubbed(:user, confirmed_at: Time.zone.now))
    assign(:token, 'foo')
    render

    expect(rendered).to have_link(
      'http://test.host/users/confirmation?confirmation_token=foo',
      href: 'http://test.host/users/confirmation?confirmation_token=foo'
    )
  end

  it 'mentions updating an account when user has already been confirmed' do
    user = build_stubbed(:user, confirmed_at: Time.zone.now)
    assign(:resource, user)
    assign(:first_sentence, user.decorate.first_sentence_for_confirmation_email)
    render

    expect(rendered).
      to have_content "To finish updating your #{APP_NAME} Account, you must confirm your email"
  end

  it 'mentions creating an account when user is not yet confirmed' do
    user = build_stubbed(:user, confirmed_at: nil)
    assign(:resource, user)
    assign(:first_sentence, user.decorate.first_sentence_for_confirmation_email)
    render

    expect(rendered).
      to have_content "To continue creating your #{APP_NAME} Account"
  end

  it 'mentions resetting the account when account has been reset by tech support' do
    user = build_stubbed(:user, reset_requested_at: Time.zone.now)
    assign(:resource, user)
    assign(:first_sentence, user.decorate.first_sentence_for_confirmation_email)
    render

    expect(rendered).
      to have_content "Your #{APP_NAME} account has been reset by a tech support representative"

    expect(rendered).
      to_not have_content "To finish creating Your #{APP_NAME} account"

    expect(rendered).
      to_not have_content "To finish updating Your #{APP_NAME} account"
  end
end
