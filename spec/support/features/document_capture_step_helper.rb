module DocumentCaptureStepHelper
  def submit_images
    click_on 'Submit'

    # Wait for the the loading interstitial to disappear before continuing
    wait_for_content_to_disappear do
      expect(page).not_to have_content(t('doc_auth.headings.interstitial'), wait: 10)
    end
  end

  def attach_and_submit_images
    attach_images
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
    click_continue
    click_button 'Take photo' if page.has_button? 'Take photo'
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

  def socure_docv_upload_documents(docv_transaction_token:)
    [
      'WAITING_FOR_USER_TO_REDIRECT',
      'APP_OPENED',
      'DOCUMENT_FRONT_UPLOADED',
      'DOCUMENT_BACK_UPLOADED',
      'DOCUMENTS_UPLOADED',
      'SESSION_COMPLETE',
    ].each { |event_type| socure_docv_send_webhook(docv_transaction_token:, event_type:) }
  end

  def socure_docv_send_webhook(
    docv_transaction_token:,
    event_type: 'DOCUMENTS_UPLOADED'
  )
    Faraday.post "http://#{[page.server.host,
                            page.server.port].join(':')}/api/webhooks/socure/event" do |req|
      req.body = {
        event: {
          eventType: event_type,
          docvTransactionToken: docv_transaction_token,
        },
      }.to_json
      req.headers = {
        'Content-Type': 'application/json',
        Authorization: "secret #{IdentityConfig.store.socure_docv_webhook_secret_key}",
      }
      req.options.context = { service_name: 'socure-docv-webhook' }
    end
  end

  def stub_docv_verification_data_pass
    stub_docv_verification_data(body: SocureDocvFixtures.pass_json)
  end

  def stub_docv_verification_data_fail_with(errors:)
    stub_docv_verification_data(body: SocureDocvFixtures.fail_json(errors))
  end

  def stub_docv_verification_pii_validation_fail
    stub_docv_verification_data(body: SocureDocvFixtures.pass_json)
    allow_any_instance_of(Idv::DocPiiForm).to receive(:valid?).and_return(false)
  end

  def stub_docv_verification_data(body:)
    stub_request(:post, "#{IdentityConfig.store.socure_idplus_base_url}/api/3.0/EmailAuthScore")
      .to_return(
        headers: {
          'Content-Type' => 'application/json',

        },
        body:,
      )
  end

  def stub_docv_document_request(
    url: 'https://verify.fake-socure.test/something',
    status: 200,
    token: SecureRandom.hex,
    body: nil
  )
    body ||= {
      referenceId: 'socure-reference-id',
      data: {
        eventId: 'socure-event-id',
        docvTransactionToken: token,
        qrCode: 'qr-code',
        url:,
      },
    }

    stub_request(:post, IdentityConfig.store.socure_docv_document_request_endpoint)
      .to_return(
        status:,
        body: body.to_json,
      )
    token
  end
end
