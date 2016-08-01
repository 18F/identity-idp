require 'rails_helper'

describe 'devise/registrations/verify_email.html.slim' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
  end

  it 'contains link to resend confirmation page' do
    render

    expect(rendered).to have_link(t('links.resend'), href: new_user_confirmation_path)
  end
end
