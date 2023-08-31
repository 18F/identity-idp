require 'rails_helper'

RSpec.describe 'sign_up/passwords/new.html.erb' do
  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:params).and_return(confirmation_token: 123)
    allow(view).to receive(:request_id).and_return(nil)

    @email_address = user.email_addresses.first
    @password_form = PasswordForm.new(user)

    render
  end

  it 'renders the correct heading' do
    expect(rendered).to have_content(t('forms.confirmation.show_hdr'))
  end

  it 'renders the proper Password label' do
    expect(rendered).to have_content(t('forms.password'))
  end

  it 'renders the proper help text' do
    expect(rendered).to have_content strip_tags(
      t(
        'instructions.password.info.lead_html',
        min_length: Devise.password_length.min,
      ),
    )
  end

  it 'includes the user email address as a hidden field' do
    # Reference:
    # - https://www.chromium.org/developers/design-documents/create-amazing-password-forms/#use-hidden-fields-for-implicit-information
    # - https://www.chromium.org/developers/design-documents/form-styles-that-chromium-understands/
    expect(user.email).to be_present
    expect(rendered).to have_css(
      "input[type='text'][name='username'][value='#{user.email}'][autocomplete='username']",
      visible: false,
    )
  end

  it 'includes a form to cancel account creation' do
    expect(rendered).to have_link(t('links.cancel_account_creation'))
  end
end
