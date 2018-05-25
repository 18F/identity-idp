require 'rails_helper'

feature 'idv jurisdiction step' do
  include IdvStepHelper

  context 'when on the jurisdiction page' do
    before do
      start_idv_from_sp
      complete_idv_steps_before_jurisdiction_step
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_jurisdiction_path)
      expect(page).to have_content(t('idv.messages.jurisdiction.why'))
    end

    context 'and selecting a supported jurisdiction' do
      it 'allows the user to continue to the profile step' do
        select 'Virginia', from: 'jurisdiction_state'
        click_idv_continue

        expect(page).to have_current_path(idv_session_path)
        expect(page).to have_content(t('idv.titles.sessions'))
      end
    end

    context 'and selecting an unsupported jurisdiction' do
      it 'fails the user' do
        select 'Alabama', from: 'jurisdiction_state'
        click_idv_continue

        expect(page).to have_current_path(idv_jurisdiction_fail_path(reason: :unsupported_jurisdiction))
        expect(page).to have_content(t('idv.titles.unsupported_jurisdiction', state: 'Alabama'))
      end
    end

    context 'when the user does not have a state-issued ID' do
      it 'renders the `no_id` fail page' do
        click_on t('idv.messages.jurisdiction.no_id')

        expect(page).to have_current_path(idv_jurisdiction_fail_path(reason: :no_id))
        expect(page).to have_content(t('idv.titles.no_id'))
      end
    end
  end

  context 'cancelling idv' do
    it_behaves_like 'cancel at idv step', :jurisdiction
    it_behaves_like 'cancel at idv step', :jurisdiction, :oidc
    it_behaves_like 'cancel at idv step', :jurisdiction, :saml
  end
end
