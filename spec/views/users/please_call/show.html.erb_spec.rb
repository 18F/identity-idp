require 'rails_helper'

RSpec.describe 'users/please_call/show.html.erb' do
  before do
    render
  end

  it 'includes a message instructing them to call contact center' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'users.suspended_sign_in_account.contact_details',
          contact_number: IdentityConfig.store.idv_contact_phone_number,
        ),
      ),
    )
  end

  it 'display support code' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'users.suspended_sign_in_account.error_details',
          error_code: 'EFGHI',
        ),
      ),
    )
  end
end
