shared_examples 'cancel at idv step' do |step, sp|
  include SamlAuthHelper

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_step(step)
  end

  it 'shows the user a cancellation message with the option to go back to the step' do
    original_path = current_path

    click_link t('links.cancel')

    expect(page).to have_content(t('headings.cancellations.prompt'))
    expect(current_path).to eq(idv_cancel_path)

    click_on t('links.go_back')

    expect(current_path).to eq(original_path)
  end

  context 'with an sp', if: sp do
    it 'shows the user a cancellation message with the option to cancel and reset idv' do
      sp_name = 'Test SP'
      allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).
        and_return(sp_name)

      click_link t('links.cancel')

      expect(page).to have_content(t('headings.cancellations.prompt'))
      expect(current_path).to eq(idv_cancel_path)

      click_on t('forms.buttons.cancel')

      expect(page).to have_content(t('headings.cancellations.confirmation', app_name: APP_NAME))
      expect(current_path).to eq(idv_cancel_path)

      expect(page).to have_link(
        "‹ #{t('links.back_to_sp', sp: sp_name)}",
        href: return_to_sp_failure_to_proof_path(step: step, location: 'cancel'),
      )

      # After visiting /verify, expect to redirect to the jurisdiction step,
      # the first step in the IdV flow
      visit idv_path
      expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
    end
  end

  context 'without an sp' do
    it 'shows a cancellation message with option to cancel and reset idv', if: sp.nil? do
      click_link t('links.cancel')

      expect(page).to have_content(t('headings.cancellations.prompt'))
      expect(current_path).to eq(idv_cancel_path)

      click_on t('forms.buttons.cancel')

      expect(page).to have_content(t('headings.cancellations.confirmation', app_name: APP_NAME))
      expect(current_path).to eq(idv_cancel_path)
      expect(page).to have_link(
        "‹ #{t('links.back_to_sp', sp: t('links.my_account'))}",
        href: account_url,
      )

      # After visiting /verify, expect to redirect to the jurisdiction step,
      # the first step in the IdV flow
      visit idv_path
      expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
    end
  end
end
