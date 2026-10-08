# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureImageRetrievalJob do
  let(:job) { described_class.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:fraud_ops_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
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
  let(:passport_book) { false }

  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:result) do
    EncryptedDocStorage::DocWriter::Result.new(name: 'name', encryption_key: '12345')
  end
  let(:selfie) { false }

  before do
    allow(AttemptsApi::Tracker).to receive(:new).and_return(attempts_api_tracker)
    allow(FraudOps::Tracker).to receive(:new).and_return(fraud_ops_tracker)
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
      document_front_image_encryption_key: Base64.strict_encode64('12345'),
    }
  end
  let(:back) do
    {
      document_back_image_file_id: 'name',
      document_back_image_encryption_key: Base64.strict_encode64('12345'),
    }
  end

  let(:image_storage_data) { { front:, back: } }

  before do
    stub_request(:get, socure_image_endpoint)
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
    let(:persist_artifacts) { false }
    let(:docv_transaction_token) { document_capture_session.socure_docv_transaction_token }
    let(:document_metadata) do
      {
        document_number: 'D-9988',
        document_issued: '2022-02-02',
        document_expiration: '2032-02-02',
      }
    end

    subject(:perform) do
      job.perform(
        reference_id:,
        document_capture_session_uuid:,
        image_storage_data:,
        passport_book:,
        persist_artifacts:,
        docv_transaction_token:,
        document_metadata:,
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

    context 'persisting document artifacts' do
      let(:persist_artifacts) { true }

      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([sp.issuer])
      end

      it 'creates one artifact per escrowed image, keyed to the capture session' do
        expect { perform }.to change { document_capture_session.document_artifacts.count }
          .from(0).to(2)

        artifact = document_capture_session.document_artifacts.find_by(image_type: 'front')
        expect(artifact.storage_name).to eq('name')
        expect(artifact.encryption_key).to eq(Base64.strict_encode64('12345'))
        expect(artifact.profile_id).to be_nil
      end

      it 'persists the document metadata encrypted, one row per capture session' do
        expect { perform }.to change { DocumentMetadata.count }.by(1)

        expect(document_capture_session.document_metadata.document_data).to eq(document_metadata)
      end

      context 'when the initiating SP is not allow-listed for image sharing' do
        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([])
        end

        it 'does not persist any key material' do
          expect { perform }.not_to change { DocumentArtifact.count }
        end

        it 'does not persist document metadata either' do
          expect { perform }.not_to change { DocumentMetadata.count }
        end
      end

      context 'when the verification attempt was not successful' do
        let(:persist_artifacts) { false }

        it 'still escrows the images but never persists shareable artifacts' do
          expect { perform }.not_to change { DocumentArtifact.count }
        end
      end

      context 'when the session started a newer Socure transaction after this job was enqueued' do
        let(:docv_transaction_token) { 'superseded-token' }

        before do
          create(
            :document_artifact,
            document_capture_session:,
            image_type: 'front',
            storage_name: 'newer-attempt-object',
          )
        end

        it 'does not overwrite the newer verification with the stale attempt' do
          perform

          front = document_capture_session.document_artifacts.find_by(image_type: 'front')
          expect(front.storage_name).to eq('newer-attempt-object')
        end
      end

      context 'when no transaction token was recorded for this attempt' do
        let(:docv_transaction_token) { nil }

        before { document_capture_session.update!(socure_docv_transaction_token: nil) }

        it 'does not persist (cannot prove which attempt the images belong to)' do
          expect { perform }.not_to change { DocumentArtifact.count }
        end
      end

      context 'when the capture session was deleted before the job ran' do
        before do
          allow(job).to receive(:fetch_images).and_wrap_original do |m, *args, **kwargs|
            job.send(:document_capture_session)
            DocumentCaptureSession.where(id: document_capture_session.id).delete_all
            m.call(*args, **kwargs)
          end
        end

        it 'no-ops instead of raising' do
          expect { perform }.not_to raise_error
        end
      end

      context 'when a prior failed attempt left artifacts of a different type on the session' do
        before do
          create(:document_artifact, document_capture_session:, image_type: 'passport')
        end

        it 'prunes the stale artifact so only the verified document remains' do
          perform

          expect(document_capture_session.document_artifacts.pluck(:image_type))
            .to contain_exactly('front', 'back')
        end
      end

      context 'when Idv::Session already stamped this session with the profile it produced' do
        let(:profile) { create(:profile, user:) }

        before { document_capture_session.update!(profile:) }

        it 'links the artifacts to that exact profile (job landed after profile creation)' do
          perform

          expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq)
            .to eq([profile.id])
        end

        it 'links the document metadata to that profile too' do
          perform

          expect(document_capture_session.document_metadata.profile_id).to eq(profile.id)
        end
      end

      context 'when the stamp is written while the job is mid-flight (backlog race)' do
        let(:profile) { create(:profile, user:) }

        before do
          # Job memoizes the session record early; simulate Idv::Session stamping the
          # row in the DB after that memoization but before reconciliation. The job
          # must read the stamp from the FOR UPDATE-locked row, not the stale memo.
          allow(job).to receive(:fetch_images).and_wrap_original do |m, *args, **kwargs|
            job.send(:document_capture_session)
            DocumentCaptureSession.where(id: document_capture_session.id)
              .update_all(profile_id: profile.id)
            m.call(*args, **kwargs)
          end
        end

        it 'still links the artifacts by reading the stamp from the locked row' do
          perform

          expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq)
            .to eq([profile.id])
        end

        it 'serializes on the capture-session row lock so a concurrent stamp is never missed' do
          expect(DocumentCaptureSession).to receive(:lock).and_call_original

          perform
        end
      end

      context 'when a type is present in the result set but its image came back blank' do
        before do
          create(:document_artifact, document_capture_session:, image_type: 'back')
          allow_any_instance_of(Idv::IdvImages).to receive(:back).and_return(nil)
        end

        it 'prunes the stale row for that type rather than keeping the old object' do
          perform

          expect(document_capture_session.document_artifacts.pluck(:image_type))
            .to contain_exactly('front')
        end
      end

      context 'when the user has an unrelated active profile but this session produced none' do
        let!(:other_profile) { create(:profile, :active, user:, verified_at: 1.minute.from_now) }

        it 'leaves the artifacts unlinked rather than guessing from the active profile' do
          perform

          expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq)
            .to eq([nil])
        end
      end

      context 'when document image sharing is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
            .and_return(false)
        end

        it 'does not persist artifacts' do
          expect { perform }.not_to change { DocumentArtifact.count }
        end
      end

      context 'when the capture session requested an mDL' do
        before { document_capture_session.request_mdl! }

        it 'does not persist artifacts' do
          expect { perform }.not_to change { DocumentArtifact.count }
        end
      end

      context 'when the job is retried (runs twice)' do
        it 'is idempotent and does not create duplicate artifacts' do
          perform
          expect { perform }.not_to change { document_capture_session.document_artifacts.count }
            .from(2)
        end
      end
    end

    context 'when we get a non-200 HTTP response back from the image endpoint' do
      let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }

      before do
        expect(EncryptedDocStorage::DocWriter).not_to receive(:new)
        expect(writer).not_to receive(:write_with_data)
      end

      context 'when we get an error without a socure response body' do
        let(:status) { 500 }
        let(:reason) { 'Unknown network error' }

        before do
          stub_request(:get, socure_image_endpoint)
            .to_return(
              status: status,
              headers: {
                'Content-Type' => 'application/json',
              },
              body: {}.to_json,
            )
        end

        it 'tracks the attempt with a fallback error' do
          expect(attempts_api_tracker).to receive(:idv_image_retrieval_failed).with(
            document_front_image_file_id: 'name',
            document_back_image_file_id: 'name',
            document_passport_image_file_id: nil,
            document_selfie_image_file_id: nil,
            failure_reason: [
              api_failure: reason,
            ],
          )

          perform
        end
      end

      %w[400 403 404 500].each do |http_status|
        let(:failure_reason) { 'Explicit failure reason' }
        let(:socure_image_response_body) { { http_status:, referenceId:, msg: } }
        let(:msg) do
          {
            status: http_status,
            msg: failure_reason,
          }
        end
        context "Socure returns HTTP #{http_status} with an error body" do
          before do
            stub_request(:get, socure_image_endpoint)
              .to_return(
                status: http_status,
                headers: {
                  'Content-Type' => 'application/json',
                },
                body: JSON.generate(socure_image_response_body),
              )
          end

          it 'tracks the attempt with an image-specific error' do
            expect(attempts_api_tracker).to receive(:idv_image_retrieval_failed).with(
              document_front_image_file_id: 'name',
              document_back_image_file_id: 'name',
              document_passport_image_file_id: nil,
              document_selfie_image_file_id: nil,
              failure_reason: [{ api_failure: failure_reason }],
            )

            perform
          end

          context 'when passport_book and selfie is true' do
            let(:passport_book) { true }
            let(:selfie) { true }
            let(:image_storage_data) do
              {
                passport: {
                  document_passport_image_file_id: 'name',
                  document_passport_image_encryption_key: Base64.strict_encode64('12345'),
                },
                selfie: {
                  document_selfie_image_file_id: 'name',
                  document_selfie_image_encryption_key: Base64.strict_encode64('12345'),
                },
              }
            end

            it 'tracks the attempt with an image-specific network error' do
              expect(attempts_api_tracker).to receive(:idv_image_retrieval_failed).with(
                document_front_image_file_id: nil,
                document_back_image_file_id: nil,
                document_passport_image_file_id: 'name',
                document_selfie_image_file_id: 'name',
                failure_reason: [{ api_failure: failure_reason }],
              )

              perform
            end
          end
        end
      end
    end
  end
end
