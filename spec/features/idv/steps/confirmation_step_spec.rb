require 'rails_helper'

feature 'idv confirmation step', :idv_job do
  include IdvStepHelper

  it_behaves_like 'idv confirmation step'

  context 'with oidc' do
    it_behaves_like 'idv confirmation step', :oidc
  end

  context 'with saml' do
    it_behaves_like 'idv confirmation step', :saml
  end

  context 'personal key information and actions' do
    before do
      personal_key = 'a1b2c3d4e5f6g7h8'

      @user = sign_in_and_2fa_user
      visit verify_session_path

      allow(RandomPhrase).to receive(:to_s).and_return(personal_key)
      complete_idv_steps_before_confirmation_step(@user)
    end

    it 'allows the user to refresh and still displays the personal key' do
      visit current_path
      expect(page).to have_content(t('headings.personal_key'))
    end

    it_behaves_like 'personal key page'
  end
end
