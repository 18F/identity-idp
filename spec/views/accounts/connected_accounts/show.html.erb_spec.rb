require 'rails_helper'
RSpec.describe 'accounts/connected_accounts/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil, personal_key: nil, user: user,
        sp_session_request_url: nil, sp_name: nil,
        locked_for_session: false
      ),
    )
  end

  it 'contains connected applications' do
    render

    expect(rendered).to have_content t('headings.account.connected_accounts')
  end

  context 'with a connected app that is an invalid service provider' do
    before do
      user.identities << create(:service_provider_identity, :active, service_provider: 'aaaaa')
    end

    it 'renders' do
      expect { render }.to_not raise_error
      expect(rendered).to match '</lg-time>'
      expect(rendered).to_not include('&lt;')
    end
  end
end
