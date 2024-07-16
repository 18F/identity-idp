require 'rails_helper'

RSpec.describe 'sign_up/select_email/show.html.erb' do
  let(:email) { 'michael.motorist@email.com' }
  let(:email2) { 'michael.motorist2@email.com' }
  let(:user) { create(:user) }

  before do
    allow(IdentityConfig.store).to receive(
      :feature_select_email_to_share_enabled,
    ).and_return(true)
    user.email_addresses.create(email: email, confirmed_at: Time.zone.now)
    user.email_addresses.create(email: email2, confirmed_at: Time.zone.now)
    user.reload
    @user_emails = user.email_addresses.map { |e| e.email }
    @select_email_form = SelectEmailForm.new(user)
  end

  it 'shows all of the user\'s emails' do
    render

    expect(rendered).to include('michael.motorist@email.com')
    expect(rendered).to include('michael.motorist2@email.com')
  end
end
