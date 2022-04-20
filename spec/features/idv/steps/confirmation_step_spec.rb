require 'rails_helper'

feature 'idv confirmation step', js: true do
  include IdvStepHelper

  it_behaves_like 'idv confirmation step'
  it_behaves_like 'idv confirmation step', :oidc
  it_behaves_like 'idv confirmation step', :saml

  context 'personal key information and actions' do
    let(:idv_api_enabled) { nil }

    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled).and_return(idv_api_enabled)

      @user = sign_in_and_2fa_user

      visit idv_path

      complete_idv_steps_before_confirmation_step(@user)
    end

    context 'when idv_api_enabled is false' do
      let(:idv_api_enabled) { false }

      it 'allows the user to refresh and still displays the personal key' do
        # Visit the current path is the same as refreshing
        visit current_path
        expect(page).to have_content(t('headings.personal_key'))
      end

      it_behaves_like 'personal key page'
    end

    context 'when idv_api_enabled is true' do
      let(:idv_api_enabled) { true }

      it 'allows the user to refresh and still displays the personal key' do
        # Visit the current path is the same as refreshing
        visit current_path
        expect(page).to have_content(t('headings.personal_key'))
      end

      it_behaves_like 'personal key page'
    end
  end
end
