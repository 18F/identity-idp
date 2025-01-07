require 'rails_helper'

RSpec.describe ImageUploadResponsePresenter do
  include Rails.application.routes.url_helpers

  let(:extra_attributes) do
    { remaining_submit_attempts: 3, flow_path: 'standard', submit_attempts: 2 }
  end

  let(:form_response) do
    FormResponse.new(success: true, errors: {}, extra: extra_attributes)
  end
  let(:presenter) { described_class.new(form_response: form_response, url_options: {}) }

  describe '#success?' do
    context 'failure' do
      let(:form_response) { FormResponse.new(success: false, errors: {}, extra: {}) }

      it 'returns false' do
        expect(presenter.success?).to eq false
      end
    end

    context 'success' do
      it 'returns true' do
        expect(presenter.success?).to eq true
      end
    end
  end

  describe '#errors' do
    context 'failure' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            front: t('doc_auth.errors.not_a_file'),
          },
          extra: {},
        )
      end

      it 'returns formatted errors' do
        expect(presenter.errors).to eq [{ field: :front, message: t('doc_auth.errors.not_a_file') }]
      end
    end

    context 'success' do
      it 'returns empty array' do
        expect(presenter.errors).to eq []
      end
    end
  end

  describe '#remaining_submit_attempts' do
    it 'returns remaining submit attempts' do
      expect(presenter.remaining_submit_attempts).to eq 3
    end
  end

  describe '#status' do
    context 'limit error' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            limit: t('doc_auth.errors.rate_limited_heading'),
          },
        )
      end

      it 'returns 429 too many requests' do
        expect(presenter.status).to eq :too_many_requests
      end
    end

    context 'failure' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            front: t('doc_auth.errors.not_a_file'),
          },
        )
      end

      it 'returns 400 bad request' do
        expect(presenter.status).to eq :bad_request
      end
    end

    context 'success' do
      it 'returns ok' do
        expect(presenter.status).to eq :ok
      end
    end
  end

  describe '#as_json' do
    context 'success' do
      it 'returns hash of properties' do
        expect(presenter.as_json).to eq(
          { success: true },
        )
      end
    end

    context 'rate limited' do
      let(:extra_attributes) do
        { remaining_submit_attempts: 0,
          flow_path: 'standard',
          failed_image_fingerprints: { back: [], front: ['12345'], selfie: [] },
          submit_attempts: 5 }
      end
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            limit: t('doc_auth.errors.rate_limited_heading'),
          },
          extra: extra_attributes,
        )
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          result_code_invalid: true,
          result_failed: false,
          errors: [{ field: :limit, message: t('doc_auth.errors.rate_limited_heading') }],
          redirect: idv_session_errors_rate_limited_url,
          remaining_submit_attempts: 0,
          ocr_pii: nil,
          doc_type_supported: true,
          failed_image_fingerprints: { back: [], front: ['12345'], selfie: [] },
          submit_attempts: 5,
        }

        expect(presenter.as_json).to eq expected
      end

      context 'hybrid flow' do
        let(:extra_attributes) do
          { remaining_submit_attempts: 0,
            flow_path: 'hybrid',
            failed_image_fingerprints: { back: [], front: ['12345'], selfie: [] },
            submit_attempts: 5 }
        end

        it 'returns hash of properties redirecting to capture_complete' do
          expected = {
            success: false,
            result_code_invalid: true,
            result_failed: false,
            errors: [{ field: :limit, message: t('doc_auth.errors.rate_limited_heading') }],
            redirect: idv_hybrid_mobile_capture_complete_url,
            remaining_submit_attempts: 0,
            ocr_pii: nil,
            doc_type_supported: true,
            failed_image_fingerprints: { back: [], front: ['12345'], selfie: [] },
            submit_attempts: 5,
          }

          expect(presenter.as_json).to eq expected
        end
      end
    end

    context 'error' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            front: t('doc_auth.errors.not_a_file'),
            hints: true,
          },
          extra: extra_attributes,
        )
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          result_code_invalid: true,
          result_failed: false,
          errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
          hints: true,
          remaining_submit_attempts: 3,
          ocr_pii: nil,
          doc_type_supported: true,
          failed_image_fingerprints: { back: [], front: [], selfie: [] },
          submit_attempts: 2,
        }

        expect(presenter.as_json).to eq expected
      end

      context 'hard fail' do
        let(:form_response) do
          FormResponse.new(
            success: false,
            errors: {
              front: t('doc_auth.errors.not_a_file'),
              hints: true,
            },
            extra: { doc_auth_result: 'Failed', remaining_submit_attempts: 3, submit_attempts: 2 },
          )
        end

        it 'returns hash of properties' do
          expected = {
            success: false,
            result_code_invalid: true,
            result_failed: true,
            errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
            hints: true,
            remaining_submit_attempts: 3,
            ocr_pii: nil,
            doc_type_supported: true,
            failed_image_fingerprints: { front: [], back: [], selfie: [] },
            submit_attempts: 2,
          }

          expect(presenter.as_json).to eq expected
        end
      end

      context 'no remaining attempts' do
        let(:extra_attributes) do
          { remaining_submit_attempts: 0, flow_path: 'standard', submit_attempts: 5 }
        end
        let(:form_response) do
          FormResponse.new(
            success: false,
            errors: {
              front: t('doc_auth.errors.not_a_file'),
              hints: true,
            },
            extra: extra_attributes,
          )
        end

        context 'hybrid flow' do
          let(:extra_attributes) do
            { remaining_submit_attempts: 0, flow_path: 'hybrid', submit_attempts: 5 }
          end

          it 'returns hash of properties' do
            expected = {
              success: false,
              result_code_invalid: true,
              result_failed: false,
              errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
              hints: true,
              redirect: idv_hybrid_mobile_capture_complete_url,
              remaining_submit_attempts: 0,
              ocr_pii: nil,
              doc_type_supported: true,
              failed_image_fingerprints: { front: [], back: [], selfie: [] },
              submit_attempts: 5,
            }

            expect(presenter.as_json).to eq expected
          end
        end

        it 'returns hash of properties' do
          expected = {
            success: false,
            result_code_invalid: true,
            result_failed: false,
            errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
            hints: true,
            redirect: idv_session_errors_rate_limited_url,
            remaining_submit_attempts: 0,
            ocr_pii: nil,
            doc_type_supported: true,
            failed_image_fingerprints: { back: [], front: [], selfie: [] },
            submit_attempts: 5,
          }

          expect(presenter.as_json).to eq expected
        end
      end
    end

    context 'pii_error' do
      describe 'there are multiple pii errors' do
        let(:form_response) do
          FormResponse.new(
            success: false,
            errors: {
              dob: 'Invalid dob',
              name: 'Missing',
            },
            extra: extra_attributes,
          )
        end
        it 'processes multiple pii errors' do
          expect(presenter.errors).to include(
            hash_including(field: :pii),
            hash_including(field: :front),
            hash_including(field: :back),
          )
        end
      end
      describe 'there is one related pii error' do
        let(:form_response) do
          FormResponse.new(
            success: false,
            errors: {
              dob_min_age: 'age too young',
            },
            extra: extra_attributes,
          )
        end
        it 'processes the pii error' do
          expect(presenter.errors).to include(
            hash_including(field: :dob_min_age),
            hash_including(
              field: :front,
              message: I18n.t('doc_auth.errors.general.multiple_front_id_failures'),
            ),
            hash_including(
              field: :back,
              message: I18n.t('doc_auth.errors.general.multiple_back_id_failures'),
            ),
          )
        end
      end
    end
    context 'with form response as attention with barcode' do
      let(:form_response) do
        response = DocAuth::Response.new(
          success: true,
          extra: { remaining_submit_attempts: 3, submit_attempts: 2 },
          pii_from_doc: Idp::Constants::MOCK_IDV_APPLICANT,
        )
        allow(response).to receive(:attention_with_barcode?).and_return(true)
        response
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          result_failed: false,
          errors: [],
          hints: true,
          remaining_submit_attempts: 3,
          ocr_pii: Idp::Constants::MOCK_IDV_APPLICANT.slice(:first_name, :last_name, :dob),
          result_code_invalid: false,
          doc_type_supported: true,
          failed_image_fingerprints: { back: [], front: [], selfie: [] },
          submit_attempts: 2,
        }

        expect(presenter.as_json).to eq expected
      end

      context 'with form response as doc type supported' do
        let(:form_response) do
          response = DocAuth::Response.new(
            success: true,
            extra: { remaining_submit_attempts: 3, submit_attempts: 2 },
            pii_from_doc: Idp::Constants::MOCK_IDV_APPLICANT,
          )
          allow(response).to receive(:attention_with_barcode?).and_return(true)
          response
        end

        it 'returns hash of properties' do
          expected = {
            success: false,
            result_failed: false,
            result_code_invalid: false,
            errors: [],
            hints: true,
            remaining_submit_attempts: 3,
            ocr_pii: Idp::Constants::MOCK_IDV_APPLICANT.slice(:first_name, :last_name, :dob),
            doc_type_supported: true,
            failed_image_fingerprints: { back: [], front: [], selfie: [] },
            submit_attempts: 2,
          }

          expect(presenter.as_json).to eq expected
        end
      end
    end
  end
end
