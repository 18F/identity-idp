# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureImageRetrievalJob do
  let(:job) { described_class.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:sp) { create(:service_provider) }
  let(:user) { create(:user) }
  let(:document_capture_session) do
    DocumentCaptureSession.create(user:).tap do |dcs|
      dcs.socure_docv_transaction_token = '1234'
    end
  end
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:reference_id) { 'image-reference-id' }
  let(:socure_image_endpoint) { "https://upload.socure.us/api/5.0/documents/#{reference_id}" }

  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:result) do
    EncryptedDocStorage::DocWriter::Result.new(name: 'name', encryption_key: '12345')
  end
  let(:selfie) { false }

  before do
    allow(AttemptsApi::Tracker).to receive(:new).and_return(attempts_api_tracker)
    allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)

    document_capture_session.update(issuer: sp.issuer)

    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
      [{ 'issuer' => sp.issuer }],
    )

    allow(writer).to receive(:write_with_data).and_return(result)
  end

  let(:front) do
    {
      document_front_image_file_id: 'name',
      document_front_image_encryption_key: '12345',
    }
  end
  let(:back) do
    {
      document_back_image_file_id: 'name',
      document_back_image_encryption_key: '12345',
    }
  end

  let(:image_storage_data) { { front:, back: } }

  before do
    stub_request(:post, socure_image_endpoint)
      .to_return(
        headers: {
          'Content-Type' => 'application/zip',
          'Content-Disposition' => 'attachment; filename=document.zip',
        },
        body: DocAuthImageFixtures.zipped_files(
          reference_id:,
          selfie:,
        ).to_s,
      )
  end

  describe '#perform' do
    subject(:perform) do
      job.perform(
        reference_id:,
        document_capture_session_uuid:,
        image_storage_data:,
      )
    end

    context 'we get a 200-http response from the image endpoint' do
      before do
        expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
        expect(writer).to receive(:write_with_data).exactly(2).times
      end

      it 'stores the images via doc escrow' do
        perform
      end
    end

    context 'when we get a non-200 HTTP response back from the image endpoint' do
      %w[400 403 404 500].each do |http_status|
        context "Socure returns HTTP #{http_status} with an error body" do
          let(:status) { 'Error' }
          let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
          let(:msg) { 'InternalServerException' }
          let(:socure_image_response_body) { { status:, referenceId:, msg: } }

          before do
            stub_request(:post, socure_image_endpoint)
              .to_return(
                status: http_status,
                headers: {
                  'Content-Type' => 'application/json',
                },
                body: JSON.generate(socure_image_response_body),
              )
          end

          before do
            expect(EncryptedDocStorage::DocWriter).not_to receive(:new)
            expect(writer).not_to receive(:write_with_data)
          end

          it 'tracks the attempt with an image-specific network error' do
            expect(attempts_api_tracker).to receive(:idv_image_retrieval_failed).with(
              **front,
              **back,
            )

            perform
          end
        end
      end
    end
  end
end
