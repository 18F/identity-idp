require 'rails_helper'

feature 'idv verify step' do
  include IdvStepHelper

  it 'allows the user to continue to the profile step' do
    start_idv_from_sp
    complete_idv_steps_before_verify_step

    expect(page).to have_current_path(idv_jurisdiction_path)
    expect(page).to have_content(t('idv.messages.jurisdiction.why'))

    select 'Virginia', from: 'jurisdiction_state'
    click_idv_continue

    expect(page).to have_content(t('idv.titles.sessions'))
    expect(page).to have_current_path(idv_session_path)
  end

  context 'cancelling idv' do
    it_behaves_like 'cancel at idv step', :verify
    it_behaves_like 'cancel at idv step', :verify, :oidc
    it_behaves_like 'cancel at idv step', :verify, :saml
  end
end
