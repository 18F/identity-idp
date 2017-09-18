require 'rails_helper'

describe 'sign_up/passwords/new.html.slim' do
  include DecoratedSessionHelper

  let(:sp_name) { '🔒🌐💻' }

  before do
    user = build_stubbed(:user)
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:params).and_return(confirmation_token: 123)
    allow(view).to receive(:request_id).and_return(nil)

    @password_form = PasswordForm.new(user)

    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)

    render
  end

  it 'renders the correct heading' do
    expect(rendered).to have_content(t('forms.confirmation.show_hdr'))
  end

  it 'renders the proper help text' do
    expect(rendered).to have_content(
      t('instructions.password.info.lead', min_length: Devise.password_length.first)
    )
  end

  it 'includes a form to cancel account creation' do
    link = t('links.cancel_account_creation')

    expect(rendered).to have_selector("input[value='#{link}']")
  end
end
