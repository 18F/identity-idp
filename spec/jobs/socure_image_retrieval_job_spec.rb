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
  let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT }
  let(:failure_reason) { {} }
  let(:success) { true }

  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:socure_doc_escrow_enabled) { false }
  let(:result) do
    EncryptedDocStorage::DocWriter::Result.new(name: 'name', encryption_key: '12345')
  end
  let(:selfie) { false }

  before do
    allow(AttemptsApi::Tracker).to receive(:new).and_return(attempts_api_tracker)
    allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)

    enable_attempts_api if socure_doc_escrow_enabled

    allow(writer).to receive(:write).and_return(result)
  end

  def enable_attempts_api
    document_capture_session.update(issuer: sp.issuer)

    allow(IdentityConfig.store).to receive(:socure_doc_escrow_enabled).and_return(
      socure_doc_escrow_enabled,
    )
    allow(IdentityConfig.store).to receive(:attempts_api_enabled).and_return(
      socure_doc_escrow_enabled,
    )
    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
      [{ 'issuer' => sp.issuer }],
    )
  end

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
        failure_reason:,
        success:,
        pii_from_doc:,
      )
    end

    context 'socure document escrow is not enabled' do
      let(:socure_doc_escrow_enabled) { false }

      before do
        expect(EncryptedDocStorage::DocWriter).not_to receive(:new)
      end

      it 'tracks the event without the images' do
        expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
          success: true,
          document_state: pii_from_doc[:state],
          document_number: pii_from_doc[:state_id_number],
          document_issued: pii_from_doc[:state_id_issued],
          document_expiration: pii_from_doc[:state_id_expiration],
          first_name: pii_from_doc[:first_name],
          last_name: pii_from_doc[:last_name],
          date_of_birth: pii_from_doc[:dob],
          address1: pii_from_doc[:address1],
          address2: pii_from_doc[:address2],
          city: pii_from_doc[:city],
          state: pii_from_doc[:state],
          zip: pii_from_doc[:zipcode],
          failure_reason: nil,
        )

        perform
      end
    end

    context 'socure document escrow is enabled' do
      let(:socure_doc_escrow_enabled) { true }

      context 'we get a 200-http response from the image endpoint' do
        before do
          expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
          expect(writer).to receive(:write).exactly(2).times
        end

        it 'stores the images via doc escrow' do
          expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
            success: true,
            document_back_image_encryption_key: '12345',
            document_back_image_file_id: 'name',
            document_front_image_encryption_key: '12345',
            document_front_image_file_id: 'name',
            document_state: pii_from_doc[:state],
            document_number: pii_from_doc[:state_id_number],
            document_issued: pii_from_doc[:state_id_issued],
            document_expiration: pii_from_doc[:state_id_expiration],
            first_name: pii_from_doc[:first_name],
            last_name: pii_from_doc[:last_name],
            date_of_birth: pii_from_doc[:dob],
            address1: pii_from_doc[:address1],
            address2: pii_from_doc[:address2],
            city: pii_from_doc[:city],
            state: pii_from_doc[:state],
            zip: pii_from_doc[:zipcode],
            failure_reason: nil,
          )

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

            it 'tracks the attempt with an image-specific network error' do
              expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
                success: true,
                document_state: pii_from_doc[:state],
                document_number: pii_from_doc[:state_id_number],
                document_issued: pii_from_doc[:state_id_issued],
                document_expiration: pii_from_doc[:state_id_expiration],
                first_name: pii_from_doc[:first_name],
                last_name: pii_from_doc[:last_name],
                date_of_birth: pii_from_doc[:dob],
                address1: pii_from_doc[:address1],
                address2: pii_from_doc[:address2],
                city: pii_from_doc[:city],
                state: pii_from_doc[:state],
                zip: pii_from_doc[:zipcode],
                failure_reason: { image_request: [:network_error] },
              )

              perform
            end
          end
        end
      end
    end

    context 'facial match' do
      let(:selfie) { true }

      context 'when facial match successful' do
        context 'socure document escrow is enabled' do
          let(:socure_doc_escrow_enabled) { true }

          before do
            expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
            expect(writer).to receive(:write).exactly(3).times
          end

          it 'stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: true,
              document_back_image_encryption_key: '12345',
              document_back_image_file_id: 'name',
              document_front_image_encryption_key: '12345',
              document_front_image_file_id: 'name',
              document_selfie_image_encryption_key: '12345',
              document_selfie_image_file_id: 'name',
              document_state: pii_from_doc[:state],
              document_number: pii_from_doc[:state_id_number],
              document_issued: pii_from_doc[:state_id_issued],
              document_expiration: pii_from_doc[:state_id_expiration],
              first_name: pii_from_doc[:first_name],
              last_name: pii_from_doc[:last_name],
              date_of_birth: pii_from_doc[:dob],
              address1: pii_from_doc[:address1],
              address2: pii_from_doc[:address2],
              city: pii_from_doc[:city],
              state: pii_from_doc[:state],
              zip: pii_from_doc[:zipcode],
              failure_reason: nil,
            )

            perform
          end
        end

        context 'socure document escrow is not enabled' do
          before do
            expect(EncryptedDocStorage::DocWriter).not_to receive(:new)
            expect(writer).not_to receive(:write)
          end

          it 'stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: true,
              document_state: pii_from_doc[:state],
              document_number: pii_from_doc[:state_id_number],
              document_issued: pii_from_doc[:state_id_issued],
              document_expiration: pii_from_doc[:state_id_expiration],
              first_name: pii_from_doc[:first_name],
              last_name: pii_from_doc[:last_name],
              date_of_birth: pii_from_doc[:dob],
              address1: pii_from_doc[:address1],
              address2: pii_from_doc[:address2],
              city: pii_from_doc[:city],
              state: pii_from_doc[:state],
              zip: pii_from_doc[:zipcode],
              failure_reason: nil,
            )

            perform
          end
        end
      end
    end
  end
end
