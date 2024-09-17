module DocumentCaptureStepHelper
  def submit_images
    click_on 'Submit'

    # Wait for the the loading interstitial to disappear before continuing
    wait_for_content_to_disappear do
      expect(page).not_to have_content(t('doc_auth.headings.interstitial'), wait: 10)
    end
  end

  def wait_for_form_page_load
    wait_for_content_to_disappear do
      expect(page).not_to have_content(t('doc_auth.headings.interstitial'), wait: 10)
    end
  end

  def continue_doc_auth_form
    click_on 'Continue'

    # Wait for the the loading interstitial to disappear before continuing
    wait_for_content_to_disappear do
      expect(page).not_to have_content(t('doc_auth.headings.interstitial'), wait: 10)
    end
  end

  def try_continue_or_submit_images
    begin
      continue_doc_auth_form
      return
    rescue
    end
    begin
      submit_images
      return
    rescue
    end
    begin
      click_idv_continue
      return
    rescue
    end
    begin
      click_idv_submit_default
      return
    rescue
    end
  end

  def attach_and_submit_images
    attach_images
    submit_images
  end

  def attach_and_submit_images_for_split_doc_auth(with_selfie: false)
    attach_images
    if with_selfie
      continue_doc_auth_form
      attach_selfie
    end
    submit_images
  end

  def attach_images(file = Rails.root.join('app', 'assets', 'images', 'email', 'logo.png'))
    attach_file t('doc_auth.headings.document_capture_front'), file, make_visible: true
    attach_file t('doc_auth.headings.document_capture_back'), file, make_visible: true
  end

  def attach_liveness_images(
    file = Rails.root.join(
      'spec', 'fixtures',
      'ial2_test_portrait_match_success.yml'
    )
  )
    attach_images(file)
    if IdentityConfig.store.doc_auth_separate_pages_enabled
      try_continue_or_submit_images
    end
    expect(page).to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
    attach_selfie
  end

  def attach_selfie(file = Rails.root.join('app', 'assets', 'images', 'email', 'logo.png'))
    attach_file t('doc_auth.headings.document_capture_selfie'), file, make_visible: true
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
    {
      document_capture_session_uuid: document_capture_session_uuid,
      front: api_image_submission_test_credential_part,
      back: api_image_submission_test_credential_part,
    }
  end

  def api_image_submission_test_credential_part
    Faraday::FilePart.new('spec/fixtures/ial2_test_credential.yml', 'text/plain')
  end

  def click_try_again
    click_spinner_button_and_wait t('idv.failure.button.warning')
  end
end
