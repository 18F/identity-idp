module DocCaptureHelper
  def complete_doc_capture_steps_before_mobile_front_image_step(user = user_with_2fa)
    dc = CaptureDoc::CreateRequest.call(user.id)
    visit idv_capture_doc_mobile_front_image_step(dc.request_token)
    dc.request_token
  end

  def complete_doc_capture_steps_before_mobile_back_image_step(user = user_with_2fa)
    complete_doc_capture_steps_before_mobile_front_image_step(user)
    mock_assure_id_ok
    attach_image
    click_idv_continue
  end

  def complete_doc_capture_steps_before_capture_complete_step(user = user_with_2fa)
    complete_doc_capture_steps_before_mobile_back_image_step(user)
    attach_image
    click_idv_continue
  end

  def idv_capture_doc_mobile_front_image_step(token)
    idv_capture_doc_step_path(step: :mobile_front_image, token: token)
  end

  def idv_capture_doc_capture_mobile_back_image_step
    idv_capture_doc_step_path(step: :capture_mobile_back_image)
  end

  def idv_capture_doc_capture_complete_step
    idv_capture_doc_step_path(step: :capture_complete)
  end

  def mock_doc_captured(user_id)
    doc_capture = CaptureDoc::CreateRequest.call(user_id)
    doc_capture.acuant_token = 'foo'
    doc_capture.save!
  end
end
