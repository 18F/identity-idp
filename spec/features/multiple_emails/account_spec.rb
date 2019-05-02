require 'rails_helper'

describe 'viewing multiple emails on the account page' do
  let(:user) do
    record = create(:user, :signed_up)
    create(:email_address, user: record)
    record.reload
  end

  it 'shows the users email addresses if the user has multiple email addresses' do
    sign_in_and_2fa_user(user)

    email_address1, email_address2 = user.email_addresses.to_a

    expect(page).to have_content(
      [
        t('account.index.email'),
        email_address1.email,
        email_address2.email,
      ].join("\n"),
    )
  end
end
