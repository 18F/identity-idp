require 'rails_helper'

feature 'IdV address step', :idv_job do
  include IdvStepHelper

  context 'the user selects phone' do
    it 'redirects them to the phone step' do
      start_idv_from_sp
      complete_idv_steps_before_address_step
      click_idv_address_choose_phone

      expect(page).to have_content(t('idv.titles.session.phone'))
      expect(page).to have_current_path(idv_phone_path)
    end
  end

  context 'the user selects usps' do
    it 'redirects them to the usps step' do
      start_idv_from_sp
      complete_idv_steps_before_address_step
      click_idv_address_choose_usps

      expect(page).to have_content(t('idv.titles.mail.verify'))
      expect(page).to have_current_path(idv_usps_path)
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :address
    it_behaves_like 'cancel at idv step', :address, :oidc
    it_behaves_like 'cancel at idv step', :address, :saml
  end
end
