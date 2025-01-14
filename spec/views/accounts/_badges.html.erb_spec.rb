require 'rails_helper'

RSpec.describe 'accounts/_badges.html.erb' do
  let(:user) { build(:user) }
  subject(:rendered) { render partial: 'accounts/badges' }

  before do
    @presenter = AccountShowPresenter.new(
      decrypted_pii: nil,
      sp_session_request_url: nil,
      authn_context: nil,
      sp_name: nil,
      user:,
      locked_for_session: false,
    )
  end

  it 'does not render anything' do
    expect(rendered).to be_empty
  end

  context 'with user having only non-phishable mfa methods' do
    let(:user) { build(:user, :with_webauthn) }

    it 'renders unphishable badge' do
      expect(rendered).to have_content(t('headings.account.unphishable'))
    end
  end
end
