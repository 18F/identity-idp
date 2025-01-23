require 'rails_helper'

RSpec.describe Idv::DocumentResponseValidator do
  subject(:validator) { described_class.new(form_response:) }

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
      success: success,
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
        context 'and there is no client_response' do
          # shouldn't happen
          it 'returns nil' do
            expect(validator.response).to eq(nil)
          end
        end

        context 'and there is a client response' do
          before do
            validator.client_response = client_response
          end

          it 'returns the client_response' do
            expect(validator.response).to eq(client_response)
          end
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

          context 'and there is no client_response' do
            # shouldn't happen
            it 'returns nil' do
              expect(validator.response).to eq(nil)
            end
          end

          context 'and there is a client response' do
            before do
              validator.client_response = client_response
            end

            it 'returns the client_response' do
              expect(validator.response).to eq(client_response)
            end
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
      subject.client_response = client_response
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
  end

  describe '#store_failed_images' do
    let(:extra_attributes) { {} }
    let(:success) { false }

    before do
      allow(document_capture_session).to receive(:store_failed_auth_data)
      allow(document_capture_session).to receive(:load_result)
      subject.client_response = client_response
      subject.store_failed_images(
        document_capture_session,
        extra_attributes,
      )
    end

    context 'if there is a front image error' do
      let(:front_image_fingerprint) { 'front fingerprint' }
      let(:extra_attributes) { { front_image_fingerprint: } }
      let(:client_response_errors) { { front: 'bad' } }

      it 'saves the front image fingerprint' do
        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint: front_image_fingerprint,
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
      let(:extra_attributes) { { back_image_fingerprint: } }
      let(:client_response_errors) { { back: 'bad' } }

      it 'saves the back image fingerprint' do
        expect(document_capture_session).to(
          have_received(:store_failed_auth_data)
            .with(
              front_image_fingerprint: nil,
              back_image_fingerprint: back_image_fingerprint,
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
