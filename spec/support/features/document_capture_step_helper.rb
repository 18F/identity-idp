module DocumentCaptureStepHelper
  def attach_and_submit_images
    attach_images

    # If selfie is required, we simulate a submission with the document capture
    # react component. As a result, the page has already been submitted so
    # submitting is a noop

    if javascript_enabled? && !selfie_required?
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
    if selfie_required?
      simulate_image_upload_api_submission
    else
      attach_file 'Front of your ID', 'app/assets/images/logo.png'
      attach_file 'Back of your ID', 'app/assets/images/logo.png'
    end
  end

  def attach_images_without_js
    attach_file 'doc_auth_front_image', 'app/assets/images/logo.png'
    attach_file 'doc_auth_back_image', 'app/assets/images/logo.png'
    attach_file 'doc_auth_selfie_image', 'app/assets/images/logo.png' if selfie_required?
  end

  def simulate_image_upload_api_submission
    connection = Faraday.new(url: document_capture_endpoint_host) do |conn|
      conn.request(:multipart)
    end
    connection.post document_capture_endpoint_path, image_upload_api_payload
    page.execute_script('document.querySelector(".js-document-capture-form").submit();')
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
