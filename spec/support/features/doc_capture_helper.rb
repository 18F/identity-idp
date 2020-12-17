module DocCaptureHelper
  def doc_capture_request_uri(user = user_with_2fa)
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('desktop')
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_link_sent_step
    url = Telephony::Test::Message.messages.last.body.split(' ').first
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_call_original
    URI.parse(url).request_uri
  end

  def in_doc_capture_session(user = user_with_2fa)
    request_uri = doc_capture_request_uri(user)
    Capybara.using_session 'doc capture' do
      allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
      visit request_uri
      yield
      allow_any_instance_of(DeviceDetector).to receive(:device_type).and_call_original
    end
  end

  def complete_doc_capture_steps_before_first_step(user = user_with_2fa)
    request_uri = doc_capture_request_uri(user)
    Capybara.reset_session!
    visit request_uri
  end

  def complete_doc_capture_steps_before_mobile_back_image_step(user = user_with_2fa)
    complete_doc_capture_steps_before_first_step(user) unless
      current_path == idv_capture_doc_mobile_front_image_step
    attach_image
    click_idv_continue
  end

  def complete_doc_capture_steps_before_document_capture_step(user = user_with_2fa)
    complete_doc_capture_steps_before_first_step(user) unless
      current_path == idv_capture_doc_document_capture_step
  end

  def complete_doc_capture_steps_before_capture_complete_step(user = user_with_2fa)
    if FeatureManagement.document_capture_step_enabled?
      complete_doc_capture_steps_before_document_capture_step
      attach_and_submit_images
    else
      complete_doc_capture_steps_before_mobile_back_image_step(user)
      attach_image
      click_idv_continue
    end
  end

  def idv_capture_doc_mobile_front_image_step
    idv_capture_doc_step_path(step: :mobile_front_image)
  end

  def idv_capture_doc_capture_mobile_back_image_step
    idv_capture_doc_step_path(step: :capture_mobile_back_image)
  end

  def idv_capture_doc_document_capture_step
    idv_capture_doc_step_path(step: :document_capture)
  end

  def idv_capture_doc_capture_complete_step
    idv_capture_doc_step_path(step: :capture_complete)
  end

  def idv_capture_doc_capture_selfie_step
    idv_capture_doc_step_path(step: :selfie)
  end

  def mock_doc_captured(user_id)
    if FeatureManagement.document_capture_step_enabled?
      user = User.find(user_id)
      response = IdentityDocAuth::Response.new(success: true)
      user.document_capture_sessions.last.store_result_from_response(response)
    else
      doc_capture = CaptureDoc::CreateRequest.call(user_id, {})
      doc_capture.acuant_token = 'foo'
      doc_capture.save!
    end
  end
end
