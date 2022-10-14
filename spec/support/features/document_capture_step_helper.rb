module DocumentCaptureStepHelper
  def submit_images
    click_on 'Submit'

    # Wait for the the loading interstitial to disappear before continuing
    expect(page).to have_content(t('doc_auth.headings.interstitial'))
    expect(page).not_to have_content(t('doc_auth.headings.interstitial'), wait: 10)
  end

  def attach_and_submit_images
    attach_images
    submit_images
  end

  def attach_images(file = 'app/assets/images/logo.png')
    attach_file t('doc_auth.headings.document_capture_front'), file
    attach_file t('doc_auth.headings.document_capture_back'), file
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
    payload
  end

  def api_image_submission_test_credential_part
    Faraday::FilePart.new('spec/fixtures/ial2_test_credential.yml', 'text/plain')
  end
end
