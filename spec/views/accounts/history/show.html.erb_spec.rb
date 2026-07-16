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
      ),
    )
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('account.dashboard.history.title')
    expect(rendered).to have_content t('headings.account.activity')
  end

  context 'with a recent event' do
    before do
      create(:event, event_type: :sign_in_after_2fa, user: user)
    end

    it 'renders the activity row title as an h3 under the section heading' do
      render

      expect(rendered).to have_css('h2', text: t('headings.account.activity'))
      expect(rendered).to have_css(
        'h3.ads-history__row-title',
        text: t('event_types.sign_in_after_2fa', app_name: APP_NAME),
      )
    end
  end
end
