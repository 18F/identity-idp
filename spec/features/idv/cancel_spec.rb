require 'rails_helper'

describe 'cancel IdV', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:sp) { nil }
  let(:fake_analytics) { FakeAnalytics.new }

  before do
    start_idv_from_sp(sp)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_agreement_step
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  it 'shows the user a cancellation message with the option to go back to the step' do
    original_path = current_path

    click_link t('links.cancel')

    expect(page).to have_content(t('headings.cancellations.prompt'))
    expect(current_path).to eq(idv_cancel_path)
    expect(fake_analytics).to have_logged_event('IdV: cancellation visited', step: 'agreement')

    click_on t('links.go_back')

    expect(current_path).to eq(original_path)
    expect(fake_analytics).to have_logged_event('IdV: cancellation go back', step: 'agreement')
  end

  it 'shows a cancellation message with option to cancel and reset idv' do
    click_link t('links.cancel')

    expect(page).to have_content(t('headings.cancellations.prompt'))
    expect(current_path).to eq(idv_cancel_path)
    expect(fake_analytics).to have_logged_event('IdV: cancellation visited', step: 'agreement')

    click_on t('forms.buttons.cancel')

    expect(page).to have_content(t('headings.cancellations.confirmation', app_name: APP_NAME))
    expect(current_path).to eq(idv_cancel_path)
    expect(page).to have_link(
      "‹ #{t('links.back_to_sp', sp: t('links.my_account'))}",
      href: account_url,
    )
    expect(fake_analytics).to have_logged_event('IdV: cancellation confirmed', step: 'agreement')

    # After visiting /verify, expect to redirect to the first step in the IdV flow.
    visit idv_path
    expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
  end

  context 'with an sp' do
    let(:sp) { :oidc }

    it 'shows the user a cancellation message with the option to cancel and reset idv' do
      sp_name = 'Test SP'
      allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).
        and_return(sp_name)

      click_link t('links.cancel')

      expect(page).to have_content(t('headings.cancellations.prompt'))
      expect(current_path).to eq(idv_cancel_path)
      expect(fake_analytics).to have_logged_event('IdV: cancellation visited', step: 'agreement')

      click_on t('forms.buttons.cancel')

      expect(page).to have_content(t('headings.cancellations.confirmation', app_name: APP_NAME))
      expect(current_path).to eq(idv_cancel_path)
      expect(fake_analytics).to have_logged_event('IdV: cancellation confirmed', step: 'agreement')

      expect(page).to have_link(
        "‹ #{t('links.back_to_sp', sp: sp_name)}",
        href: return_to_sp_failure_to_proof_path(step: 'agreement', location: 'cancel'),
      )

      # After visiting /verify, expect to redirect to the first step in the IdV flow.
      visit idv_path
      expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
    end
  end
end
