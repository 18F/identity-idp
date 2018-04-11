shared_examples 'cancel at idv step' do |sp|
  include SamlAuthHelper

  before do
    if sp.present?
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
    else
      visit root_path
    end
    complete_previous_idv_steps
  end

  context 'without js' do
    it 'sends the user to the account page', if: sp.present? do
      click_idv_cancel
      expect(current_url).to eq(account_url)
    end

    it 'shows the user a failure message with the option to go back to idv', if: sp.nil? do
      click_link t('links.cancel')

      expect(page).to have_content(t('idv.titles.cancel'))
      expect(page).to have_content(t('idv.messages.cancel', app: 'login.gov'))
      expect(current_path).to eq(verify_cancel_path)

      click_link t('forms.buttons.back')

      expect(current_url).to eq(verify_url)
    end
  end

  context 'with js', :js do
    it 'displays a modal with options to continue or return to account page', if: sp.present? do
      # Clicking cancel displays the modal
      click_on t('links.cancel_idv')
      expect(page).to have_content(t('idv.cancel.modal_header'))

      # Clicking continue should hide the modal
      click_on t('idv.buttons.continue')
      expect(page).to_not have_content(t('idv.cancel.modal_header'))

      # Clicking cancel again reveals the modal
      click_on t('links.cancel_idv')
      expect(page).to have_content(t('idv.cancel.modal_header'))

      # Clicking return to account takes us to the account page
      page.find_button(t('idv.buttons.cancel')).trigger('click')
      expect(page).to have_content(t('headings.account.login_info'))
      expect(current_path).to eq(account_path)
    end

    it 'shows the user a failure message with the option to go back to idv', if: sp.nil? do
      click_link t('links.cancel')

      expect(page).to have_content(t('idv.titles.cancel'))
      expect(page).to have_content(t('idv.messages.cancel', app: 'login.gov'))
      expect(current_path).to eq(verify_cancel_path)

      click_link t('forms.buttons.back')

      expect(current_path).to eq(verify_path)
    end
  end
end
