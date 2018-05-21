require 'rails_helper'

feature 'IdV with previous address filled in', idv_job: true do
  include IdvStepHelper

  let(:bad_zipcode) { '00000' }
  let(:current_address) { '123 Main St' }
  let(:previous_address) { '456 Other Ave' }

  def expect_to_stay_on_verify_session_page
    expect(current_path).to eq idv_session_result_path
    expect(page).to have_selector("input[value='#{bad_zipcode}']")
  end

  def expect_bad_current_address_to_fail
    fill_out_idv_previous_address_ok
    fill_out_idv_form_fail
    click_idv_continue

    expect_to_stay_on_verify_session_page
  end

  def expect_current_address_in_profile(user)
    fill_out_idv_form_ok
    fill_out_idv_previous_address_ok
    click_idv_continue

    click_idv_address_choose_phone
    fill_out_phone_form_ok(user.phone)
    click_idv_continue

    expect(current_path).to eq idv_review_path
    expect(page).to have_content(current_address)
    expect(page).to_not have_content(previous_address)
  end

  it 'fails when current address has bad value, prefers current address in profile' do
    user = user_with_2fa
    start_idv_from_sp
    complete_idv_steps_before_profile_step(user)

    expect_bad_current_address_to_fail
    expect_current_address_in_profile(user)
  end

  it 'closing previous address accordion clears inputs and toggles header', :js do
    start_idv_from_sp
    complete_idv_steps_before_profile_step

    expect(page).to have_css('.accordion-header-controls',
                             text: t('idv.form.previous_address_add'))

    click_accordion
    expect(page).to have_css('.accordion-header', text: t('links.remove'))

    fill_out_idv_previous_address_ok
    expect(find('#profile_prev_address1').value).to eq '456 Other Ave'

    click_accordion
    click_accordion

    expect(find('#profile_prev_address1').value).to eq ''
  end

  def click_accordion
    find('.accordion-header-controls[aria-controls="previous-address"]').click
  end
end
