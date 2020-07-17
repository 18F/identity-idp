require 'rails_helper'

feature 'document capture step' do
  include IdvStepHelper
  include DocAuthHelper
  include InPersonHelper

  let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
  let(:user) { user_with_2fa }
  let(:liveness_enabled) { 'false' }
  before do
    allow(Figaro.env).to receive(:document_capture_step_enabled).
      and_return(document_capture_step_enabled)
    allow(Figaro.env).to receive(:liveness_checking_enabled).
      and_return(liveness_enabled)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_document_capture_step
  end

  context 'when the step is disabled' do
    let(:document_capture_step_enabled) { 'false' }

    it 'takes the user to the front image step' do
      expect(current_path).to eq(idv_doc_auth_front_image_step)
    end
  end

  context 'when the step is enabled' do
    let(:document_capture_step_enabled) { 'true' }

    context 'when liveness checking is enabled' do
      let(:liveness_enabled) { 'true' }

      it 'is on the correct_page' do
        expect(current_path).to eq(idv_doc_auth_document_capture_step)
        expect(page).to have_content(render_html_string(t('doc_auth.headings.upload_front_html')))
        expect(page).to have_content(render_html_string(t('doc_auth.headings.upload_back_html')))
        expect(page).to have_content(t('doc_auth.headings.selfie'))
      end

      it 'displays tips and sample images' do
        expect(page).to have_content(I18n.t('doc_auth.tips.text1'))
        expect(page).to have_css('img[src*=state-id-sample-front]')
      end

      it 'proceeds to the next page with valid info' do
        attach_images
        click_idv_continue

        expect(page).to have_current_path(next_step)
      end

      it 'allows the use of a base64 encoded data url representation of the image' do
        attach_front_image_data_url
        attach_back_image_data_url
        attach_selfie_image_data_url
        click_idv_continue

        expect(page).to have_current_path(next_step)
        expect(DocAuthMock::DocAuthMockClient.last_uploaded_front_image).to eq(
          doc_auth_front_image_data_url_data,
        )
        expect(DocAuthMock::DocAuthMockClient.last_uploaded_back_image).to eq(
          doc_auth_back_image_data_url_data,
        )
        expect(DocAuthMock::DocAuthMockClient.last_uploaded_selfie_image).to eq(
          doc_auth_selfie_image_data_url_data,
        )
      end

      it 'does not proceed to the next page with invalid info' do
        mock_general_doc_auth_client_error(:create_document)
        attach_images
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_document_capture_step)
      end

      it 'offers in person option on failure' do
        enable_in_person_proofing

        expect(page).to_not have_link(t('in_person_proofing.opt_in_link'),
                                      href: idv_in_person_welcome_step)

        mock_general_doc_auth_client_error(:create_document)
        attach_images
        click_idv_continue

        expect(page).to have_link(t('in_person_proofing.opt_in_link'),
                                  href: idv_in_person_welcome_step)
      end

      it 'throttles calls to acuant and allows retry after the attempt window' do
        allow(Figaro.env).to receive(:acuant_max_attempts).and_return(max_attempts)
        max_attempts.times do
          attach_images
          click_idv_continue

          expect(page).to have_current_path(next_step)
          click_on t('doc_auth.buttons.start_over')
          complete_doc_auth_steps_before_document_capture_step
        end

        attach_images
        click_idv_continue

        expect(page).to have_current_path(idv_session_errors_throttled_path)

        Timecop.travel(Figaro.env.acuant_attempt_window_in_minutes.to_i.minutes.from_now) do
          sign_in_and_2fa_user(user)
          complete_doc_auth_steps_before_document_capture_step
          attach_images
          click_idv_continue

          expect(page).to have_current_path(next_step)
        end
      end

      it 'catches network connection errors on post_front_image' do
        DocAuthMock::DocAuthMockClient.mock_response!(
          method: :post_front_image,
          response: Acuant::Response.new(
            success: false,
            errors: [I18n.t('errors.doc_auth.acuant_network_error')],
          ),
        )

        attach_images
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_document_capture_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end
  end

  def next_step
    idv_doc_auth_ssn_step
  end

  def render_html_string(text)
    rendered = Nokogiri::HTML.parse(text).text
    strip_nbsp(rendered)
  end
end
