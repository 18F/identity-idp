shared_examples 'cancel at idv step' do |step, sp|
  include SamlAuthHelper

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_step(step)
  end

  it 'shows the user a cancellation message with the option to go back to the step' do
    original_path = current_path

    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.modal_header'))
    expect(current_path).to eq(idv_cancel_path)

    click_on t('links.go_back')

    expect(current_path).to eq(original_path)
  end

  it 'shows the user a cancellation message with the option to cancel and reset idv' do
    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.modal_header'))
    expect(current_path).to eq(idv_cancel_path)

    click_on t('forms.buttons.cancel')

    expect(page).to have_content(t('headings.cancellations.confirmation'))
    expect(current_path).to eq(idv_cancel_path)

    # After visiting /verify, expect to redirect to the jurisdiction step,
    # the first step in the IdV flow
    visit idv_path
    expect(current_path).to eq(idv_jurisdiction_path)
  end
end
