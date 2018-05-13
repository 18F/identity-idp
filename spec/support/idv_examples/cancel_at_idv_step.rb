shared_examples 'cancel at idv step' do |step, sp|
  include SamlAuthHelper

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_step(step)
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
      expect(current_path).to eq(idv_cancel_path)

      click_link t('forms.buttons.back')

      expect(current_url).to eq(idv_url)
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
      click_button t('idv.buttons.cancel')
      expect(page).to have_content(t('headings.account.login_info'))
      expect(current_path).to eq(account_path)
    end

    it 'shows the user a failure message with the option to go back to idv', if: sp.nil? do
      click_link t('links.cancel')

      expect(page).to have_content(t('idv.titles.cancel'))
      expect(page).to have_content(t('idv.messages.cancel', app: 'login.gov'))
      expect(current_path).to eq(idv_cancel_path)

      click_link t('forms.buttons.back')

      expect(current_path).to eq(idv_path)
    end
  end
end
