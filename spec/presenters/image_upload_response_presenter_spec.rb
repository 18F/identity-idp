require 'rails_helper'

describe ImageUploadResponsePresenter do
  include Rails.application.routes.url_helpers

  let(:form) { Idv::ApiImageUploadForm.new({}, liveness_checking_enabled: false) }
  let(:form_response) { FormResponse.new(success: true, errors: {}, extra: {}) }
  let(:presenter) { described_class.new(form: form, form_response: form_response) }

  before do
    allow(Throttler::RemainingCount).to receive(:call).and_return(3)
    allow(DocumentCaptureSession).to receive(:find_by).and_return(
      DocumentCaptureSession.create!(requested_at: Time.zone.now),
    )
  end

  describe '#success' do
    context 'failure' do
      let(:form_response) { FormResponse.new(success: false, errors: {}, extra: {}) }

      it 'returns false' do
        expect(presenter.success).to eq false
      end
    end

    context 'success' do
      it 'returns true' do
        expect(presenter.success).to eq true
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
            limit: t('errors.doc_auth.acuant_throttle'),
          },
        )
      end

      it 'returns bad request' do
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

      it 'returns bad request' do
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

    context 'throttled' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            limit: t('errors.doc_auth.acuant_throttle'),
          },
          extra: {},
        )
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          redirect: idv_session_errors_throttled_url,
        }

        expect(presenter.as_json).to eq expected
      end
    end

    context 'error' do
      let(:form_response) do
        FormResponse.new(
          success: false,
          errors: {
            front: t('doc_auth.errors.not_a_file'),
          },
          extra: {},
        )
      end

      it 'returns hash of properties' do
        expected = {
          success: false,
          errors: [{ field: :front, message: t('doc_auth.errors.not_a_file') }],
          remaining_attempts: 3,
        }

        expect(presenter.as_json).to eq expected
      end
    end
  end
end
