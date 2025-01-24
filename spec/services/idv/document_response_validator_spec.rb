require 'rails_helper'

RSpec.describe Idv::DocumentResponseValidator do
  subject(:validator) do
    validator = described_class.new(form_response:, client_response:)
    validator.instance_variable_set(:@doc_pii_response, doc_pii_response) if doc_pii_response
    validator
  end

  let(:extra) do
    {
      remaining_submit_attempts: 1,
      flow_path: nil,
      liveness_checking_required: false,
      submit_attempts: 1,
      pii_like_keypaths: [[:pii], [:error_details], [:dob], [:dob_min_age]],
    }
  end

  let(:document_capture_session) { DocumentCaptureSession.create }
  let(:analytics) { FakeAnalytics.new }


  let(:client_response) do
    DocAuth::Response.new(
      success: client_success,
      pii_from_doc: pii_from_doc,
      errors: client_response_errors,
    )
  end
  let(:client_success) { true }
  let(:client_response_errors) { {} }
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

  let(:doc_pii_response) do
    Idv::DocAuthFormResponse.new(
      success: doc_pii_success,
      errors: doc_pii_errors,
      extra: doc_pii_extra,
    )
  end
  let(:doc_pii_success) { true }
  let(:doc_pii_errors) { {} }
  let(:doc_pii_extra) { {} }

  let(:form_response) do
    Idv::DocAuthFormResponse.new(success: form_response_success, errors: {}, extra:)
  end
  let(:form_response_success) { true }

  describe '#response' do
    context 'when the form response fails' do
      let(:form_response_success) { false }

      it 'returns the form_response' do
        expect(validator.response).to eq(form_response)
      end
    end

    context 'when the form response succeeds' do
      context 'and there is no doc_pii_response' do
        let(:doc_pii_response) { nil }

        it 'returns the client_response' do
          expect(validator.response).to eq(client_response)
        end
      end

      context 'and there is a doc_pii_response' do
        context 'which passes' do
          it 'returns the client_response' do
            expect(validator.response).to eq(client_response)
          end
        end

        context 'which fails' do
          let(:doc_pii_success) { false }

          it 'returns the doc_pii_response' do
            expect(validator.response).to eq(doc_pii_response)
          end
        end
      end
    end
  end

  describe '#validate_pii_from_doc' do
    let(:doc_pii_response) { nil }

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
      let(:client_success) { false }

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
    let(:client_success) { false }
    let(:capture_result) { subject.store_failed_images(document_capture_session, extra) }

    let(:front_image_fingerprint) { nil }
    let(:back_image_fingerprint) { nil }
    let(:client_response_errors) { {} }

    before do
      allow(document_capture_session).to receive(:store_failed_auth_data).and_call_original
      allow(document_capture_session).to receive(:load_result).and_call_original
    end

    context 'if there is only a front image error' do
      let(:front_image_fingerprint) { 'front fingerprint' }
      let(:extra) { { front_image_fingerprint: } }
      let(:client_response_errors) { { front: 'bad' } }

      it 'saves only the front image fingerprint' do
        expect(capture_result[:front]).not_to be_empty
        expect(capture_result[:back]).to be_empty

        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint:,
              back_image_fingerprint: nil,
              doc_auth_success: client_success,
              selfie_image_fingerprint: nil,
              selfie_status: :not_processed,
            ),
        )
      end
    end

    context 'if there is only a back image error' do
      let(:back_image_fingerprint) { 'back fingerprint' }
      let(:extra) { { back_image_fingerprint: } }
      let(:client_response_errors) { { back: 'bad' } }

      it 'saves only the back image fingerprint' do
        expect(capture_result[:front]).to be_empty
        expect(capture_result[:back]).not_to be_empty

        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint: nil,
              back_image_fingerprint:,
              doc_auth_success: client_success,
              selfie_image_fingerprint: nil,
              selfie_status: :not_processed,
            ),
        )
      end
    end

    context 'if there is a front image error and a back image error' do
      let(:front_image_fingerprint) { 'front fingerprint' }
      let(:back_image_fingerprint) { 'back fingerprint' }
      let(:extra) { { front_image_fingerprint:, back_image_fingerprint: } }
      let(:client_response_errors) { { front: 'bad', back: 'bad' } }

      it 'saves both the front image fingerprint and the back image fingerprint' do
        expect(capture_result[:front]).not_to be_empty
        expect(capture_result[:back]).not_to be_empty

        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint:,
              back_image_fingerprint:,
              doc_auth_success: client_success,
              selfie_image_fingerprint: nil,
              selfie_status: :not_processed,
            ),
        )
      end
    end

    context 'when client_response is a network error' do
      let(:network_error) { true }

      it 'stores neither of the side as failed' do
        expect(capture_result[:front]).to be_empty
        expect(capture_result[:back]).to be_empty
      end
    end

    it 'reloads the document capture session result' do
      capture_result

      expect(document_capture_session).to have_received(:load_result).at_least(:once)
    end
  end
end
