module DocAuthHelper
  ACUANT_RESULTS = {
    'Result' => 1,
    'Fields' => [
      { 'Name' => 'First Name', 'Value' => 'Jane' },
      { 'Name' => 'Middle Name', 'Value' => 'Ann' },
      { 'Name' => 'Surname', 'Value' => 'Doe' },
      { 'Name' => 'Address Line 1', 'Value' => '1 Street' },
      { 'Name' => 'Address City', 'Value' => 'New York' },
      { 'Name' => 'Address State', 'Value' => 'NY' },
      { 'Name' => 'Address Postal Code', 'Value' => '11364' },
      { 'Name' => 'Birth Date', 'Value' => '/Date(' +
        (Date.strptime('10-05-1938', '%m-%d-%Y').strftime('%Q').to_i + 43_200_000).to_s + ')/' },
    ],
  }.freeze

  ACUANT_RESULTS_TO_PII =
    {
      first_name: 'Jane',
      middle_name: 'Ann',
      last_name: 'Doe',
      address1: '1 Street',
      city: 'New York',
      state: 'NY',
      zipcode: '11364',
      dob: '10/05/1938',
      ssn: '123',
      phone: '456',
      state_id_jurisdiction: nil,
      state_id_number: nil,
      state_id_type: 'drivers_license',
    }.freeze

  def session_from_completed_flow_steps(finished_step)
    session = { doc_auth: {} }
    Idv::Flows::DocAuthFlow::STEPS.each do |step, klass|
      session[:doc_auth][klass.to_s] = true
      return session if step == finished_step
    end
    session
  end

  def fill_out_ssn_form_with_duplicate_ssn
    diff_user = create(:user)
    create(:profile, pii: { ssn: '123-45-6666' }, user: diff_user)
    fill_in 'doc_auth_ssn', with: '123-45-6666'
  end

  def fill_out_ssn_form_with_ssn_that_fails_resolution
    fill_in 'doc_auth_ssn', with: '123-45-6666'
  end

  def fill_out_ssn_form_ok
    fill_in 'doc_auth_ssn', with: '666-66-1234'
  end

  def fill_out_ssn_form_fail
    fill_in 'doc_auth_ssn', with: ''
  end

  def idv_doc_auth_welcome_step
    idv_doc_auth_step_path(step: :welcome)
  end

  def idv_doc_auth_upload_step
    idv_doc_auth_step_path(step: :upload)
  end

  def idv_doc_auth_ssn_step
    idv_doc_auth_step_path(step: :ssn)
  end

  def idv_doc_auth_front_image_step
    idv_doc_auth_step_path(step: :front_image)
  end

  def idv_doc_auth_mobile_front_image_step
    idv_doc_auth_step_path(step: :mobile_front_image)
  end

  def idv_doc_auth_back_image_step
    idv_doc_auth_step_path(step: :back_image)
  end

  def idv_doc_auth_mobile_back_image_step
    idv_doc_auth_step_path(step: :mobile_back_image)
  end

  def idv_doc_auth_success_step
    idv_doc_auth_step_path(step: :doc_success)
  end

  def idv_doc_auth_verify_step
    idv_doc_auth_step_path(step: :verify)
  end

  def idv_doc_auth_self_image_step
    idv_doc_auth_step_path(step: :self_image)
  end

  def idv_doc_auth_send_link_step
    idv_doc_auth_step_path(step: :send_link)
  end

  def idv_doc_auth_link_sent_step
    idv_doc_auth_step_path(step: :link_sent)
  end

  def idv_doc_auth_email_sent_step
    idv_doc_auth_step_path(step: :email_sent)
  end

  def complete_doc_auth_steps_before_welcome_step(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    visit idv_doc_auth_welcome_step unless current_path == idv_doc_auth_welcome_step
  end

  def complete_doc_auth_steps_before_upload_step(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    visit idv_doc_auth_welcome_step unless current_path == idv_doc_auth_welcome_step
    find('input[name="ial2_consent_given"]').set(true)
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_front_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_upload_step(user)
    click_on t('doc_auth.buttons.use_computer')
  end

  def complete_doc_auth_steps_before_mobile_front_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_upload_step(user)
    allow(DeviceDetector).to receive(:new).and_return(mobile_device)
    click_on t('doc_auth.buttons.use_phone')
  end

  def mobile_device
    DeviceDetector.new('Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) \
AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1')
  end

  def complete_doc_auth_steps_before_ssn_step(user = user_with_2fa)
    complete_doc_auth_steps_before_back_image_step(user)
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_back_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_front_image_step(user)
    mock_assure_id_ok
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_mobile_back_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_mobile_front_image_step(user)
    mock_assure_id_ok
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_doc_success_step(user = user_with_2fa)
    complete_doc_auth_steps_before_verify_step(user)
    click_idv_continue
  end

  def complete_doc_auth_steps_before_address_step(user = user_with_2fa)
    complete_doc_auth_steps_before_verify_step(user)
    click_link t('doc_auth.buttons.change_address')
  end

  def complete_doc_auth_steps_before_verify_step(user = user_with_2fa)
    complete_doc_auth_steps_before_ssn_step(user)
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_self_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_doc_success_step(user)
    click_idv_continue
  end

  def complete_doc_auth_steps_before_send_link_step(user = user_with_2fa)
    complete_doc_auth_steps_before_upload_step(user)
    click_on t('doc_auth.buttons.use_phone')
  end

  def complete_doc_auth_steps_before_link_sent_step(user = user_with_2fa)
    complete_doc_auth_steps_before_send_link_step(user)
    fill_out_doc_auth_phone_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_email_sent_step(user = user_with_2fa)
    allow(DeviceDetector).to receive(:new).and_return(mobile_device)
    complete_doc_auth_steps_before_upload_step(user)
    click_on t('doc_auth.buttons.use_computer')
  end

  def mock_assure_id_ok
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:create_document).
      and_return([true, '123'])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_front_image).
      and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
      and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
      and_return([true, ACUANT_RESULTS.dup])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:face_image).and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::FacialMatch).to receive(:call).
      and_return([true, { 'FacialMatch' => 1 }])
  end

  def mock_assure_id_fail
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:create_document).
      and_return([false, ''])
    allow_any_instance_of(Idv::Acuant::FakeAssureId).to receive(:create_document).
      and_return([false, ''])
  end

  def enable_doc_auth
    allow(FeatureManagement).to receive(:doc_auth_enabled?).and_return(true)
    allow(FeatureManagement).to receive(:doc_auth_exclusive?).and_return(true)
  end

  def enable_test_credentials
    allow(FeatureManagement).to receive(:allow_doc_auth_test_credentials?).and_return(true)
  end

  def attach_image
    attach_file 'doc_auth_image', 'app/assets/images/logo.png'
  end

  def assure_id_results_with_result_2
    result = DocAuthHelper::ACUANT_RESULTS.dup
    result['Result'] = 2
    result['Alerts'] = [{ 'Actions': 'Check the document' }]
    result
  end

  def fill_out_address_form_ok
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '66044'
  end

  def fill_out_address_form_resolution_fail
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '00000'
  end

  def fill_out_address_form_fail
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '1'
  end

  def fill_out_doc_auth_phone_form_ok(phone = '415-555-0199')
    fill_in :doc_auth_phone, with: phone
  end
end
