require 'rails_helper'

RSpec.describe 'anonymous_mailer/password_reset_missing_user.html.erb' do
  let(:request_id) { SecureRandom.uuid }

  before do
    assign(:request_id, request_id)
  end

  subject(:rendered) { render }

  it 'links to trying another email, maintaining request id' do
    expect(rendered).to have_link(
      t('anonymous_mailer.password_reset_missing_user.try_different_email'),
      href: new_user_password_url(request_id:),
    )
  end

  it 'links to create an account, maintaining request id' do
    expect(rendered).to have_link(
      t('anonymous_mailer.password_reset_missing_user.create_new_account'),
      href: sign_up_register_url(request_id:),
    )
  end
end
