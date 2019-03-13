require 'rails_helper'

feature 'Unphishable account badge' do
  before do
    sign_in_and_2fa_user(user)
  end

  context 'with unphishable configuration' do
    let(:user) { create(:user, :with_webauthn, :with_piv_or_cac) }

    it 'shows an "Unphishable" badge' do
      expect(page).to have_css('img#unphishable_badge')
    end
  end

  context 'with phishable configuration' do
    let(:user) { create(:user, :signed_up, :with_webauthn) }

    it 'does not show an "Unphishable" badge' do
      expect(page).to_not have_css('img#unphishable_badge')
    end
  end
end
