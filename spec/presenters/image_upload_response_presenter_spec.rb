require 'rails_helper'

RSpec.describe ImageUploadResponsePresenter do
  include Rails.application.routes.url_helpers

  let(:extra_attributes) do
    { remaining_attempts: 3, flow_path: 'standard' }
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

  describe '#remaining_attempts' do
    it 'returns remaining attempts' do
      expect(presenter.remaining_attempts).to eq 3
    end
  end

  describe '#status' do
    context 'limit error' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            limit: t('errors.doc_auth.throttled_heading'),
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
        { remaining_attempts: 0, flow_path: 'standard' }
      end
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            limit: t('errors.doc_auth.throttled_heading'),
          },
          extra: extra_attributes,
        )
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          result_failed: false,
          errors: [{ field: :limit, message: t('errors.doc_auth.throttled_heading') }],
          redirect: idv_session_errors_throttled_url,
          remaining_attempts: 0,
          ocr_pii: nil,
        }

        expect(presenter.as_json).to eq expected
      end

      context 'hybrid flow' do
        let(:extra_attributes) do
          { remaining_attempts: 0, flow_path: 'hybrid' }
        end

        it 'returns hash of properties redirecting to capture_complete' do
          expected = {
            success: false,
            result_failed: false,
            errors: [{ field: :limit, message: t('errors.doc_auth.throttled_heading') }],
            redirect: idv_hybrid_mobile_capture_complete_url,
            remaining_attempts: 0,
            ocr_pii: nil,
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
          result_failed: false,
          errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
          hints: true,
          remaining_attempts: 3,
          ocr_pii: nil,
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
            extra: { doc_auth_result: 'Failed', remaining_attempts: 3 },
          )
        end

        it 'returns hash of properties' do
          expected = {
            success: false,
            result_failed: true,
            errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
            hints: true,
            remaining_attempts: 3,
            ocr_pii: nil,
          }

          expect(presenter.as_json).to eq expected
        end
      end

      context 'no remaining attempts' do
        let(:extra_attributes) do
          { remaining_attempts: 0, flow_path: 'standard' }
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
            { remaining_attempts: 0, flow_path: 'hybrid' }
          end

          it 'returns hash of properties' do
            expected = {
              success: false,
              result_failed: false,
              errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
              hints: true,
              redirect: idv_hybrid_mobile_capture_complete_url,
              remaining_attempts: 0,
              ocr_pii: nil,
            }

            expect(presenter.as_json).to eq expected
          end
        end

        it 'returns hash of properties' do
          expected = {
            success: false,
            result_failed: false,
            errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
            hints: true,
            redirect: idv_session_errors_throttled_url,
            remaining_attempts: 0,
            ocr_pii: nil,
          }

          expect(presenter.as_json).to eq expected
        end
      end
    end

    context 'with form response as attention with barcode' do
      let(:form_response) do
        response = DocAuth::Response.new(
          success: true,
          extra: { remaining_attempts: 3 },
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
          remaining_attempts: 3,
          ocr_pii: Idp::Constants::MOCK_IDV_APPLICANT.slice(:first_name, :last_name, :dob),
        }

        expect(presenter.as_json).to eq expected
      end
    end
  end
end
