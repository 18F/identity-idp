module DocumentCaptureStepHelper
  def attach_and_submit_images
    attach_images

    if javascript_enabled?
      click_on 'Submit'
      # Wait for the background image job to finish and success flash to appear before continuing
      expect(page).to have_content(t('doc_auth.headings.interstitial'))

      Capybara.using_wait_time(10) do
        expect(page).to have_content(t('doc_auth.headings.capture_complete'))
      end
    elsif !javascript_enabled?
      click_idv_continue
    end
  end

  def attach_images
    if javascript_enabled?
      attach_images_with_js
    else
      attach_images_without_js
    end
  end

  def attach_images_with_js
    attach_file t('doc_auth.headings.document_capture_front'), 'app/assets/images/logo.png'
    attach_file t('doc_auth.headings.document_capture_back'), 'app/assets/images/logo.png'
    if selfie_required?
      # Disable `mediaDevices` support so that selfie upload does not attempt a live capture, and
      # instead falls back to image upload.
      page.execute_script('Object.defineProperty(navigator, "mediaDevices", { value: undefined });')
      click_idv_continue
      attach_file t('doc_auth.headings.document_capture_selfie'), 'app/assets/images/logo.png'
    end
  end

  def attach_images_without_js
    attach_file 'doc_auth_front_image', 'app/assets/images/logo.png'
    attach_file 'doc_auth_back_image', 'app/assets/images/logo.png'
    attach_file 'doc_auth_selfie_image', 'app/assets/images/logo.png' if selfie_required?
  end

  def document_capture_form
    page.find('#document-capture-form')
  end

  def document_capture_session_uuid
    document_capture_form['data-document-capture-session-uuid']
  end

  def document_capture_endpoint_uri
    URI.parse(document_capture_form['data-endpoint'])
  end

  def document_capture_endpoint_host
    uri = document_capture_endpoint_uri
    uri.path = ''
    uri.to_s
  end

  def document_capture_endpoint_path
    document_capture_endpoint_uri.path
  end

  def image_upload_api_payload
    payload = {
      document_capture_session_uuid: document_capture_session_uuid,
      front: api_image_submission_test_credential_part,
      back: api_image_submission_test_credential_part,
    }
    payload[:selfie] = api_image_submission_test_credential_part if selfie_required?
    payload
  end

  def api_image_submission_test_credential_part
    Faraday::FilePart.new('spec/fixtures/ial2_test_credential.yml', 'text/plain')
  end

  def selfie_required?
    page.find('#document-capture-form')['data-liveness-required'] == 'true'
  end
end
