module DocCaptureHelper
  def doc_capture_request_uri(user = user_with_2fa)
    allow_any_instance_of(Browser).to receive(:mobile?).and_return(false)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_link_sent_step
    url = Telephony::Test::Message.messages.last.body.split(' ')[1]
    allow_any_instance_of(Browser).to receive(:mobile?).and_call_original
    URI.parse(url).request_uri
  end

  def in_doc_capture_session(user = user_with_2fa)
    request_uri = doc_capture_request_uri(user)
    Capybara.using_session 'doc capture' do
      allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
      visit request_uri
      yield
      allow_any_instance_of(Browser).to receive(:mobile?).and_call_original
    end
  end

  def complete_doc_capture_steps_before_first_step(user = user_with_2fa)
    request_uri = doc_capture_request_uri(user)
    Capybara.reset_session!
    visit request_uri
  end

  def using_doc_capture_session(user = user_with_2fa)
    request_uri = doc_capture_request_uri(user)
    Capybara.using_session('mobile') do
      visit request_uri
      yield
    end
  end

  def complete_doc_capture_steps_before_document_capture_step(user = user_with_2fa)
    complete_doc_capture_steps_before_first_step(user) unless
      current_path == idv_capture_doc_document_capture_step
  end

  def complete_doc_capture_steps_before_capture_complete_step(user = user_with_2fa)
    complete_doc_capture_steps_before_document_capture_step(user)
    attach_and_submit_images
  end

  def idv_capture_doc_document_capture_step
    idv_capture_doc_step_path(step: :document_capture)
  end

  def idv_capture_doc_capture_complete_step
    idv_capture_doc_step_path(step: :capture_complete)
  end

  def mock_doc_captured(user_id, response = DocAuth::Response.new(success: true))
    user = User.find(user_id)
    user.document_capture_sessions.last.store_result_from_response(response)
  end
end
