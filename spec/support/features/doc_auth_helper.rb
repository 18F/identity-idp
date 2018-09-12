module DocAuthHelper
  ACUANT_RESULTS = {
    'Result' =>  1,
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
    }.freeze

  def session_from_completed_flow_steps(finished_step)
    session = { doc_auth: {} }
    Idv::Flows::DocAuthFlow::STEPS.each do |step, klass|
      session[:doc_auth][klass.to_s] = true
      return session if step == finished_step
    end
    session
  end

  def fill_out_ssn_form_ok
    fill_in 'doc_auth_ssn', with: '666-66-1234'
  end

  def fill_out_ssn_form_fail
    fill_in 'doc_auth_ssn', with: ''
  end

  def idv_doc_auth_ssn_step
    idv_doc_auth_step_path(step: :ssn)
  end

  def idv_doc_auth_front_image_step
    idv_doc_auth_step_path(step: :front_image)
  end

  def idv_doc_auth_back_image_step
    idv_doc_auth_step_path(step: :back_image)
  end

  def idv_doc_auth_doc_success_step
    idv_doc_auth_step_path(step: :doc_success)
  end

  def idv_doc_auth_doc_failed_step
    idv_doc_auth_step_path(step: :doc_failed)
  end

  def idv_doc_auth_self_image_step
    idv_doc_auth_step_path(step: :self_image)
  end

  def complete_doc_auth_steps_before_ssn_step(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    visit idv_doc_auth_ssn_step unless current_path == idv_doc_auth_ssn_step
  end

  def complete_doc_auth_steps_before_front_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_ssn_step(user)
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_back_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_front_image_step(user)
    mock_assure_id_ok
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_doc_success_step(user = user_with_2fa)
    complete_doc_auth_steps_before_back_image_step(user)
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_doc_failed_step(user = user_with_2fa)
    complete_doc_auth_steps_before_back_image_step(user)
    attach_image
    click_idv_continue
  end

  def complete_doc_auth_steps_before_self_image_step(user = user_with_2fa)
    complete_doc_auth_steps_before_doc_success_step(user)
    click_idv_continue
  end

  def mock_assure_id_ok
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:create_document).
      and_return([true, '123'])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_front_image).
      and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
      and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
      and_return([true, ACUANT_RESULTS])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:face_image).and_return([true, ''])
    allow_any_instance_of(Idv::Acuant::FacialMatch).to receive(:call).
      and_return([true, { 'FacialMatch' => 1 }])
  end

  def mock_assure_id_fail
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:create_document).
      and_return([false, ''])
  end

  def enable_doc_auth
    allow(FeatureManagement).to receive(:doc_auth_enabled?).and_return(true)
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
end
