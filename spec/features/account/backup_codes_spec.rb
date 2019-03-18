require 'rails_helper'

feature 'Backup codes' do
  before do
    sign_in_and_2fa_user(user)
  end

  context 'with backup codes' do
    let(:user) { create(:user, :with_backup_code) }

    it 'shows backup code section' do
      expect(page).to have_xpath("//div/em[starts-with(text(),'generated')]")
    end
  end

  context 'without backup codes just phone' do
    let(:user) { create(:user, :signed_up) }

    it 'does not show backup code section' do
      expect(page).to have_xpath("//div/em[starts-with(text(),'not generated')]")
    end
  end
end
