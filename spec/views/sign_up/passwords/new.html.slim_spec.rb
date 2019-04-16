require 'rails_helper'

describe 'sign_up/passwords/new.html.slim' do
  before do
    user = build_stubbed(:user)
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:params).and_return(confirmation_token: 123)
    allow(view).to receive(:request_id).and_return(nil)

    @password_form = PasswordForm.new(user)

    render
  end

  it 'renders the correct heading' do
    expect(rendered).to have_content(t('forms.confirmation.show_hdr'))
  end

  it 'renders the proper help text' do
    expect(rendered).to have_content(
      t('instructions.password.info.lead', min_length: Devise.password_length.first),
    )
  end

  it 'includes a form to cancel account creation' do
    expect(rendered).to have_link(t('links.cancel_account_creation'))
  end
end
