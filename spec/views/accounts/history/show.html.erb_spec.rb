require 'rails_helper'

describe 'accounts/history/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(user).to receive(:decorate).and_return(decorated_user)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        personal_key: nil,
        decorated_user: decorated_user,
        sp_session_request_url: nil,
        sp_name: nil,
        locked_for_session: false,
      ),
    )
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('account.navigation.history')
    expect(rendered).to have_content t('headings.account.activity')
  end
end
