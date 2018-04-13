require 'rails_helper'

feature 'IdV phone number input', :idv_job, :js do
  include IdvStepHelper

  before do
    start_idv_from_sp
    complete_idv_steps_before_phone_step
  end

  scenario 'phone input only allows numbers' do
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('abcd1234')

    expect(find('#idv_phone_form_phone').value).to eq '1 (234) '
  end

  scenario 'phone input does not format international numbers' do
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('+81543543643')

    expect(find('#idv_phone_form_phone').value).to eq '+1 (815) 435-4364'
  end
end
