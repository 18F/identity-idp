require 'rails_helper'

RSpec.describe Idv::DocumentResponseValidator do
  subject(:validator) { described_class.new(form_response:, client_response:) }

  let(:success) { true }
  let(:errors) { {} }

  let(:extra) do
    {
      remaining_submit_attempts: 1,
      flow_path: nil,
      liveness_checking_required: false,
      submit_attempts: 1,
      pii_like_keypaths: [[:pii], [:error_details], [:dob], [:dob_min_age]],
    }
  end

  let(:client_response_errors) { nil }

  let(:pii_from_doc) do
    {
      first_name: 'first_name',
      middle_name: 'middle_name',
      last_name: 'last_name',
      name_suffix: 'name_suffix',
      address1: 'address1',
      address2: 'address2',
      city: 'city',
      state: 'WI',
      zipcode: 'zipcode',
      dob: '2000-1-1',
      sex: 'sex',
      height: 'height',
      weight: 'weight',
      eye_color: 'eye_color',
      state_id_number: 'state_id_number',
      state_id_issued: '2025-1-1',
      state_id_expiration: '2026-1-1',
      state_id_type: 'state_id_type',
      state_id_jurisdiction: 'WI',
      issuing_country_code: 'issuing_country_code',
    }
  end

  let(:client_response) do
    DocAuth::Response.new(
      success:,
      pii_from_doc: pii_from_doc,
      errors: client_response_errors,
    )
  end

  let(:document_capture_session) { DocumentCaptureSession.create }
  let(:analytics) { FakeAnalytics.new }

  let(:form_response) do
    Idv::DocAuthFormResponse.new(success:, errors:, extra:)
  end

  describe '#response' do
    let(:form_response) { double('form_response') }
    let(:doc_pii_response) { double('doc_pii_response') }
    let(:client_response) { double('client_response') }

    context 'when the form response fails' do
      before do
        allow(form_response).to receive(:success?).and_return(false)
      end

      it 'returns the form_response' do
        expect(validator.response).to eq(form_response)
      end
    end

    context 'when the form response succeeds' do
      before do
        allow(form_response).to receive(:success?).and_return(true)
      end

      context 'and there is no doc_pii_response' do
        it 'returns the client_response' do
          expect(validator.response).to eq(client_response)
        end
      end

      context 'and there is a doc_pii_response' do
        before do
          validator.doc_pii_response = doc_pii_response
        end

        context 'which passes' do
          before do
            allow(doc_pii_response).to receive(:success?).and_return(true)
          end

          it 'returns the client_response' do
            expect(validator.response).to eq(client_response)
          end
        end

        context 'which fails' do
          before do
            allow(doc_pii_response).to receive(:success?).and_return(false)
          end

          it 'returns the doc_pii_response' do
            expect(validator.response).to eq(doc_pii_response)
          end
        end
      end
    end
  end

  describe '#validate_pii_from_doc' do
    before do
      allow(document_capture_session).to receive(:store_result_from_response)
      subject.validate_pii_from_doc(
        document_capture_session:,
        extra_attributes: extra,
        analytics:,
      )
    end

    context 'when we have a successful client_response' do
      it 'stores the client response' do
        expect(document_capture_session).to(
          have_received(:store_result_from_response)
            .with(client_response),
        )
      end

      it 'sets the doc_pii_response' do
        expect(subject.doc_pii_response).not_to be_nil
      end
    end

    context 'when we have a failed client response' do
      let(:success) { false }

      it 'does not store the client response' do
        expect(document_capture_session).not_to(
          have_received(:store_result_from_response)
            .with(client_response),
        )
      end

      it 'does not set the doc_pii_response' do
        expect(subject.doc_pii_response).to be_nil
      end
    end
  end

  describe '#store_failed_images' do
    let(:extra) { {} }
    let(:success) { false }

    before do
      allow(document_capture_session).to receive(:store_failed_auth_data)
      allow(document_capture_session).to receive(:load_result)

      subject.store_failed_images(document_capture_session, extra)
    end

    context 'if there is a front image error' do
      let(:front_image_fingerprint) { 'front fingerprint' }
      let(:extra) { { front_image_fingerprint: } }
      let(:client_response_errors) { { front: 'bad' } }

      it 'saves the front image fingerprint' do
        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint:,
              back_image_fingerprint: nil,
              doc_auth_success: success,
              selfie_image_fingerprint: nil,
              selfie_status: :not_processed,
            )
        )
      end
    end

    context 'if there is a back image error' do
      let(:back_image_fingerprint) { 'back fingerprint' }
      let(:extra) { { back_image_fingerprint: } }
      let(:client_response_errors) { { back: 'bad' } }

      it 'saves the back image fingerprint' do
        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint: nil,
              back_image_fingerprint:,
              doc_auth_success: success,
              selfie_image_fingerprint: nil,
              selfie_status: :not_processed,
            ),
        )
      end
    end

    it 'reloads the document capture session result' do
      expect(document_capture_session).to have_received(:load_result)
    end
  end
end

RSpec.context 'old ApiImageUploadForm specs' do
  include DocPiiHelper

  subject(:form) do
    Idv::ApiImageUploadForm.new(
      ActionController::Parameters.new(
        {
          front: front_image,
          front_image_metadata: front_image_metadata.to_json,
          back: back_image,
          back_image_metadata: back_image_metadata.to_json,
          selfie: selfie_image,
          selfie_image_metadata: selfie_image_metadata.to_json,
          document_capture_session_uuid: document_capture_session_uuid,
        }.compact,
      ),
      service_provider: build(:service_provider, issuer: 'test_issuer'),
      analytics: fake_analytics,
      liveness_checking_required: liveness_checking_required,
      doc_auth_vendor: 'mock',
      acuant_sdk_upgrade_ab_test_bucket:,
    )
  end

  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:selfie_image) { nil }
  let(:liveness_checking_required) { false }
  let(:front_image_file_name) { 'front.jpg' }
  let(:back_image_file_name) { 'back.jpg' }
  let(:selfie_image_file_name) { 'selfie.jpg' }
  let(:front_image_metadata) do
    {
      width: 40,
      height: 40,
      mimeType: 'image/png',
      source: 'upload',
      fileName: front_image_file_name,
    }
  end

  let(:back_image_metadata) do
    {
      width: 20,
      height: 20,
      mimeType: 'image/png',
      source: 'upload',
      fileName: back_image_file_name,
    }
  end

  let(:selfie_image_metadata) { nil }
  let!(:document_capture_session) { DocumentCaptureSession.create!(user: create(:user)) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:acuant_sdk_upgrade_ab_test_bucket) {}

  let(:doc_pii_response) { instance_double(Idv::DocAuthFormResponse) }
  let(:client_response) { instance_double(DocAuth::Response) }
  let(:capture_result)  { form.send(:store_failed_images) }
  let(:network_error) { 'network_error_not_set' }
  let(:doc_pii_success) { 'doc_pii_success_not_set' }

  let(:errors) { {} }

  before do
    allow(client_response).to receive(:success?).and_return(false)
    allow(client_response).to receive(:errors).and_return(errors)
    allow(client_response).to receive(:selfie_status).and_return(:not_processed)
    allow(client_response).to receive(:network_error?).and_return(network_error)
    allow(client_response).to receive(:doc_auth_success?).and_return(doc_pii_success)

    allow(doc_pii_response).to receive(:success?).and_return(doc_pii_success)

    form.send(:validate_form)

    form.document_response_validator = Idv::DocumentResponseValidator.new(
      form_response: form.form_response,
      client_response:,
    )
    form.document_response_validator.doc_pii_response = doc_pii_response
  end

  describe '#store_failed_images' do
    context 'when client_response is not success and not network error' do
      let(:network_error) { false }
      let(:doc_pii_success) { false }

      context 'when both sides error message missing' do
        let(:errors) { {} }

        it 'stores both sides as failed' do
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end

      context 'when both sides error message exist' do
        let(:errors) { { front: 'blurry', back: 'dpi' } }

        it 'stores both sides as failed' do
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end

      context 'when one sides error message exists' do
        let(:errors) { { front: 'blurry', back: nil } }

        it 'stores only the error side as failed' do
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).to be_empty
        end
      end
    end

    context 'when client_response is not success and is network error' do
      let(:network_error) { true }

      context 'when doc_pii_response is success' do
        let(:doc_pii_success) { true }

        it 'stores neither of the side as failed' do
          expect(capture_result[:front]).to be_empty
          expect(capture_result[:back]).to be_empty
        end
      end

      context 'when doc_pii_response is failure' do
        let(:doc_pii_success) { false }

        it 'stores both sides as failed' do
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end
    end
  end
end
