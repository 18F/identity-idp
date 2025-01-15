require 'rails_helper'

RSpec.describe 'accounts/history/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
        change_email_available: false,
      ),
    )
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('account.navigation.history')
    expect(rendered).to have_content t('headings.account.activity')
  end
end
