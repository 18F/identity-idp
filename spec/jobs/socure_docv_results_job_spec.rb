# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureDocvResultsJob do
  let(:job) { described_class.new }
  let(:user) { create(:user) }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:sp) { create(:service_provider) }
  let(:socure_docv_transaction_token) { 'abcd' }
  let(:document_capture_session) { DocumentCaptureSession.create(user:) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:socure_idplus_base_url) { 'https://example.com' }
  let(:decision_value) { 'accept' }
  let(:expiration_date) { "#{1.year.from_now.year}-01-01" }
  let(:document_type_type) { 'Drivers License' }
  let(:reason_codes) { %w[I831 R810] }
  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:socure_doc_escrow_enabled) { false }
  let(:selfie) { false }

  before do
    document_capture_session.update(
      socure_docv_transaction_token:,
      issuer: sp.issuer,
    )
    allow(IdentityConfig.store).to receive(:socure_idplus_base_url)
      .and_return(socure_idplus_base_url)
    allow(Analytics).to receive(:new).and_return(fake_analytics)
    allow(AttemptsApi::Tracker).to receive(:new).and_return(attempts_api_tracker)

    enable_attempts_api if socure_doc_escrow_enabled
  end

  def enable_attempts_api
    allow(IdentityConfig.store).to receive(:socure_doc_escrow_enabled).and_return(
      socure_doc_escrow_enabled,
    )
    allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
    allow(writer).to receive(:write_with_data)

    allow(IdentityConfig.store).to receive(:attempts_api_enabled).and_return(
      socure_doc_escrow_enabled,
    )

    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
      [{ 'issuer' => sp.issuer }],
    )
  end

  describe '#perform' do
    subject(:perform) do
      job.perform(document_capture_session_uuid:)
    end

    subject(:perform_now) do
      job.perform(document_capture_session_uuid:, async: false)
    end

    context 'when we get a 200 OK back from Socure' do
      let(:socure_response_body) do
        # ID+ v3.0 API Predictive Document Verification response
        {
          referenceId: 'a1234b56-e789-0123-4fga-56b7c890d123',
          previousReferenceId: 'e9c170f2-b3e4-423b-a373-5d6e1e9b23f8',
          documentVerification: {
            reasonCodes: reason_codes,
            documentType: {
              type: document_type_type,
              country: 'USA',
              state: 'NY',
            },
            decision: {
              name: 'lenient',
              value: decision_value,
            },
            documentData: {
              firstName: 'Dwayne',
              surName: 'Denver',
              fullName: 'Dwayne Denver',
              address: '123 Example Street, New York City, NY 10001',
              parsedAddress: {
                physicalAddress: '123 Example Street',
                physicalAddress2: 'Apt 4',
                city: 'New York City',
                state: 'NY',
                country: 'US',
                zip: '10001',
              },
              documentNumber: '000000000',
              dob: '2000-01-01',
              issueDate: '2020-01-01',
              expirationDate: expiration_date,
            },
          },
          customerProfile: {
            customerUserId: user.uuid,
            userId: 'u8JpWn4QsF3R7tA2',
          },
        }
      end

      let(:expected_socure_log) do
        {
          success: true,
          issue_year: 2020,
          vendor: 'Socure',
          submit_attempts: 0,
          remaining_submit_attempts: 4,
          state: 'NY',
          zip_code: '10001',
          doc_auth_success: true,
          document_type: {
            type: document_type_type,
            country: 'USA',
            state: 'NY',
          },
          customer_user_id: user.uuid,
        }
      end

      let(:pii_from_doc) { socure_response_body[:documentVerification][:documentData] }
      let(:address_data) { pii_from_doc[:parsedAddress] }

      before do
        stub_request(:post, "#{socure_idplus_base_url}/api/3.0/EmailAuthScore")
          .with(body: {
            modules: ['documentverification'],
            docvTransactionToken: socure_docv_transaction_token,
            customerUserId: user.uuid,
            email: user.last_sign_in_email_address.email,
          })
          .to_return(
            headers: {
              'Content-Type' => 'application/json',
            },
            body: JSON.generate(socure_response_body),
          )

        stub_request(:get, "https://upload.socure.us/api/5.0/documents/#{socure_response_body[:referenceId]}")
          .to_return(
            headers: {
              'Content-Type' => 'application/zip',
              'Content-Disposition' => 'attachment; filename=document.zip',
            },
            body: DocAuthImageFixtures.zipped_files(
              reference_id: socure_response_body[:referenceId],
              selfie:,
            ).to_s,
          )
      end

      it 'stores the result from the Socure DocV request' do
        expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
          success: true,
          document_state: address_data[:state],
          document_number: pii_from_doc[:documentNumber],
          document_issued: Date.parse(pii_from_doc[:issueDate]),
          document_expiration: Date.parse(pii_from_doc[:expirationDate]),
          first_name: pii_from_doc[:firstName],
          last_name: pii_from_doc[:surName],
          date_of_birth: Date.parse(pii_from_doc[:dob]),
          address1: address_data[:physicalAddress],
          address2: address_data[:physicalAddress2],
          city: address_data[:city],
          state: address_data[:state],
          zip: address_data[:zip],
          failure_reason: nil,
        )
        perform

        document_capture_session.reload
        document_capture_session_result = document_capture_session.load_result
        expect(document_capture_session_result.success).to eq(true)
        expect(document_capture_session_result.pii[:first_name]).to eq('Dwayne')
        expect(document_capture_session_result.attention_with_barcode).to eq(false)
        expect(document_capture_session_result.doc_auth_success).to eq(true)
        expect(document_capture_session_result.selfie_status).to eq(:not_processed)
        expect(document_capture_session.last_doc_auth_result).to eq('accept')
      end

      context 'document escrow is enabled' do
        let(:socure_doc_escrow_enabled) { true }

        context 'we get a 200-http response from the image endpoint' do
          before do
            expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
            expect(writer).to receive(:write_with_data).exactly(2).times
          end

          it 'stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: true,
              document_back_image_encryption_key: an_instance_of(String),
              document_back_image_file_id: an_instance_of(String),
              document_front_image_encryption_key: an_instance_of(String),
              document_front_image_file_id: an_instance_of(String),
              document_state: address_data[:state],
              document_number: pii_from_doc[:documentNumber],
              document_issued: Date.parse(pii_from_doc[:issueDate]),
              document_expiration: Date.parse(pii_from_doc[:expirationDate]),
              first_name: pii_from_doc[:firstName],
              last_name: pii_from_doc[:surName],
              date_of_birth: Date.parse(pii_from_doc[:dob]),
              address1: address_data[:physicalAddress],
              address2: address_data[:physicalAddress2],
              city: address_data[:city],
              state: address_data[:state],
              zip: address_data[:zip],
              failure_reason: nil,
            )

            perform
          end
        end

        context 'when we get a non-200 HTTP response back from the image endpoint' do
          let(:socure_doc_escrow_enabled) { true }

          %w[400 403 404 500].each do |http_status|
            context "Socure returns HTTP #{http_status} with an error body" do
              let(:status) { 'Error' }
              let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
              let(:msg) { 'InternalServerException' }
              let(:socure_image_response_body) { { status:, referenceId:, msg: } }
              let(:doc_escrow_name) { 'doc_escrow_name' }
              let(:doc_escrow_key) { 'doc_escrow_key' }

              before do
                stub_request(:get, "https://upload.socure.us/api/5.0/documents/#{socure_response_body[:referenceId]}")
                  .to_return(
                    status: http_status,
                    headers: {
                      'Content-Type' => 'application/json',
                    },
                    body: JSON.generate(socure_image_response_body),
                  )
              end

              before do
                allow(job).to receive(:doc_escrow_name).and_return(doc_escrow_name)
                allow(job).to receive(:doc_escrow_key).and_return(doc_escrow_key)
              end

              it 'tracks the attempt with an image-specific network error' do
                expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
                  success: true,
                  document_back_image_encryption_key: doc_escrow_key,
                  document_back_image_file_id: doc_escrow_name,
                  document_front_image_encryption_key: doc_escrow_key,
                  document_front_image_file_id: doc_escrow_name,
                  document_state: address_data[:state],
                  document_number: pii_from_doc[:documentNumber],
                  document_issued: Date.parse(pii_from_doc[:issueDate]),
                  document_expiration: Date.parse(pii_from_doc[:expirationDate]),
                  first_name: pii_from_doc[:firstName],
                  last_name: pii_from_doc[:surName],
                  date_of_birth: Date.parse(pii_from_doc[:dob]),
                  address1: address_data[:physicalAddress],
                  address2: address_data[:physicalAddress2],
                  city: address_data[:city],
                  state: address_data[:state],
                  zip: address_data[:zip],
                  failure_reason: nil,
                )

                expect(attempts_api_tracker).to receive(:idv_image_retrieval_failed).with(
                  document_back_image_file_id: doc_escrow_name,
                  document_front_image_file_id: doc_escrow_name,
                  document_passport_image_file_id: nil,
                  document_selfie_image_file_id: nil,
                )

                perform
              end
            end
          end
        end
      end

      context 'facial match' do
        let(:reason_codes_selfie_fail) { ['no match', 'not live'] }
        let(:reason_codes_selfie_not_processed) { ['not procesed'] }
        let(:reason_codes_selfie_pass) { ['match', 'live'] }
        let(:selfie) { true }

        before do
          allow(IdentityConfig.store).to receive(:idv_socure_reason_codes_docv_selfie_pass)
            .and_return(reason_codes_selfie_pass)
          allow(IdentityConfig.store).to receive(:idv_socure_reason_codes_docv_selfie_fail)
            .and_return(reason_codes_selfie_fail)
          allow(IdentityConfig.store).to receive(:idv_socure_reason_codes_docv_selfie_not_processed)
            .and_return(reason_codes_selfie_not_processed)
        end

        context 'when facial match successful' do
          let(:reason_codes) { reason_codes_selfie_pass }
          it 'selfies status is :success' do
            perform

            document_capture_session.reload
            document_capture_session_result = document_capture_session.load_result
            expect(document_capture_session_result.selfie_status).to eq(:success)
          end

          context 'document escrow is enabled' do
            let(:socure_doc_escrow_enabled) { true }

            before do
              expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
              expect(writer).to receive(:write_with_data).exactly(3).times
            end

            it 'stores the images via doc escrow' do
              expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
                success: true,
                document_back_image_encryption_key: an_instance_of(String),
                document_back_image_file_id: an_instance_of(String),
                document_front_image_encryption_key: an_instance_of(String),
                document_front_image_file_id: an_instance_of(String),
                document_selfie_image_encryption_key: an_instance_of(String),
                document_selfie_image_file_id: an_instance_of(String),
                document_state: address_data[:state],
                document_number: pii_from_doc[:documentNumber],
                document_issued: Date.parse(pii_from_doc[:issueDate]),
                document_expiration: Date.parse(pii_from_doc[:expirationDate]),
                first_name: pii_from_doc[:firstName],
                last_name: pii_from_doc[:surName],
                date_of_birth: Date.parse(pii_from_doc[:dob]),
                address1: address_data[:physicalAddress],
                address2: address_data[:physicalAddress2],
                city: address_data[:city],
                state: address_data[:state],
                zip: address_data[:zip],
                failure_reason: nil,
              )

              perform
            end
          end
        end

        context 'when facial match fails' do
          let(:reason_codes) { reason_codes_selfie_fail }
          it 'selfies status is :fail' do
            perform

            document_capture_session.reload
            document_capture_session_result = document_capture_session.load_result
            expect(document_capture_session_result.selfie_status).to eq(:fail)
          end

          context 'and the socure result response is a failure' do
            let(:decision_value) { 'failed' }
            context 'doc escrow is enabled' do
              let(:socure_doc_escrow_enabled) { true }

              it 'stores the images via doc escrow' do
                expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
                  success: false,
                  document_back_image_encryption_key: an_instance_of(String),
                  document_back_image_file_id: an_instance_of(String),
                  document_front_image_encryption_key: an_instance_of(String),
                  document_front_image_file_id: an_instance_of(String),
                  document_selfie_image_encryption_key: an_instance_of(String),
                  document_selfie_image_file_id: an_instance_of(String),
                  document_state: address_data[:state],
                  document_number: pii_from_doc[:documentNumber],
                  document_issued: Date.parse(pii_from_doc[:issueDate]),
                  document_expiration: Date.parse(pii_from_doc[:expirationDate]),
                  first_name: pii_from_doc[:firstName],
                  last_name: pii_from_doc[:surName],
                  date_of_birth: Date.parse(pii_from_doc[:dob]),
                  address1: address_data[:physicalAddress],
                  address2: address_data[:physicalAddress2],
                  city: address_data[:city],
                  state: address_data[:state],
                  zip: address_data[:zip],
                  failure_reason: { reason_codes: reason_codes_selfie_fail },
                )

                perform
              end
            end
          end
        end

        context 'when facial match is not processed code received' do
          let(:reason_codes) { reason_codes_selfie_not_processed }
          it 'selfies status is :not_processed' do
            perform

            document_capture_session.reload
            document_capture_session_result = document_capture_session.load_result
            expect(document_capture_session_result.selfie_status).to eq(:not_processed)
          end
        end

        context 'when no facial match docs are received' do
          let(:reason_codes) { ['random code'] }
          it 'selfies status is :not_processed' do
            perform

            document_capture_session.reload
            document_capture_session_result = document_capture_session.load_result
            expect(document_capture_session_result.selfie_status).to eq(:not_processed)
          end
        end
      end

      context 'Identification Card is submitted' do
        let(:document_type_type) { 'Identification Card' }
        it 'doc auth succeeds' do
          perform

          document_capture_session.reload
          document_capture_session_result = document_capture_session.load_result
          expect(document_capture_session_result.success).to eq(true)
          expect(document_capture_session_result.pii[:first_name]).to eq('Dwayne')
          expect(document_capture_session_result.attention_with_barcode).to eq(false)
          expect(document_capture_session_result.doc_auth_success).to eq(true)
          expect(document_capture_session_result.selfie_status).to eq(:not_processed)
          expect(document_capture_session.last_doc_auth_result).to eq('accept')
          expect(fake_analytics).to have_logged_event(
            :idv_socure_verification_data_requested,
            hash_including(
              :customer_user_id,
              :decision,
              :reference_id,
            ),
          )
        end
      end

      context 'Passport is submitted' do
        let(:document_type_type) { 'Passport' }
        let(:mrz) { 'P<USADWAYNE<<DENVER<<<<<<<<<<<<<<<<<<<<<<<<<' }
        let(:socure_response_body) do
          # ID+ v3.0 API Predictive Document Verification response
          {
            referenceId: 'a1234b56-e789-0123-4fga-56b7c890d123',
            previousReferenceId: 'e9c170f2-b3e4-423b-a373-5d6e1e9b23f8',
            documentVerification: {
              reasonCodes: reason_codes,
              documentType: {
                type: document_type_type,
                country: 'USA',
              },
              decision: {
                name: 'lenient',
                value: decision_value,
              },
              documentData: {
                firstName: 'Dwayne',
                surName: 'Denver',
                fullName: 'Dwayne Denver',
                documentNumber: '000000000',
                dob: '2000-01-01',
                issueDate: '2020-01-01',
                expirationDate: expiration_date,
              },
              rawData: { mrz: },
            },
            customerProfile: {
              customerUserId: user.uuid,
              userId: 'u8JpWn4QsF3R7tA2',
            },
          }
        end

        context 'when docv passports are NOT enabled' do
          it 'doc auth fails' do
            perform

            document_capture_session.reload
            document_capture_session_result = document_capture_session.load_result
            expect(document_capture_session_result.success).to eq(false)
            expect(document_capture_session_result.pii[:mrz]).to eq(mrz)
            expect(document_capture_session_result.doc_auth_success).to eq(false)
            expect(document_capture_session_result.selfie_status).to eq(:not_processed)
            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
              hash_including(
                :customer_user_id,
                :decision,
                :reference_id,
              ),
            )
          end
        end

        context 'when passports are enabled' do
          before do
            allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
          end

          it 'logs the Socure verification data requested event' do
            perform

            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
              hash_including(
                :customer_user_id,
                :decision,
                :reference_id,
              ),
            )
          end
          context 'when a passport result is returned' do
            it 'doc auth fails' do
              perform

              document_capture_session.reload
              document_capture_session_result = document_capture_session.load_result
              expect(document_capture_session_result.success).to eq(false)
              expect(document_capture_session_result.pii[:mrz]).to eq(mrz)
              expect(document_capture_session_result.doc_auth_success).to eq(false)
              expect(document_capture_session_result.selfie_status).to eq(:not_processed)
            end

            context 'when docv passports are enabled' do
              before do
                allow(Rails.env).to receive(:development?).and_return(true)
                allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default)
                  .and_return(Idp::Constants::Vendors::SOCURE)
                document_capture_session.update!(
                  passport_status: 'requested',
                )
              end

              it 'doc auth succeeds' do
                perform

                document_capture_session.reload
                document_capture_session_result = document_capture_session.load_result
                expect(document_capture_session_result.success).to eq(true)
                expect(document_capture_session_result.pii[:mrz]).to eq(mrz)
                expect(document_capture_session_result.doc_auth_success).to eq(true)
                expect(document_capture_session_result.selfie_status).to eq(:not_processed)
              end

              context 'when pii validation fails' do
                let(:mrz) { nil }

                it 'doc auth fails' do
                  perform

                  document_capture_session.reload
                  document_capture_session_result = document_capture_session.load_result
                  expect(document_capture_session_result.success).to eq(false)
                  expect(document_capture_session_result.errors[:pii_validation]).to eq('failed')
                  expect(document_capture_session_result.doc_auth_success).to eq(true)
                  expect(document_capture_session_result.selfie_status).to eq(:not_processed)
                end
              end

              context 'when decision is not "accept"' do
                let(:decision_value) { 'reject' }

                it 'doc auth fails' do
                  perform

                  document_capture_session.reload
                  document_capture_session_result = document_capture_session.load_result
                  expect(document_capture_session_result.success).to eq(false)
                  expect(document_capture_session_result.doc_auth_success).to eq(false)
                  expect(document_capture_session_result.selfie_status).to eq(:not_processed)
                end
              end
            end
          end
        end
      end

      context 'not accepted document type' do
        let(:document_type_type) { 'Non-Document-Type' }
        it 'doc auth fails' do
          perform

          document_capture_session.reload
          document_capture_session_result = document_capture_session.load_result
          expect(document_capture_session_result.success).to eq(false)
          expect(document_capture_session_result.pii[:first_name]).to eq('Dwayne')
          expect(document_capture_session_result.errors).to eq({ unaccepted_id_type: true })
          expect(document_capture_session_result.attention_with_barcode).to eq(false)
          expect(document_capture_session_result.doc_auth_success).to eq(false)
          expect(document_capture_session_result.selfie_status).to eq(:not_processed)
        end

        context 'doc escrow is enabled' do
          let(:socure_doc_escrow_enabled) { true }

          it 'stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: false,
              document_back_image_encryption_key: an_instance_of(String),
              document_back_image_file_id: an_instance_of(String),
              document_front_image_encryption_key: an_instance_of(String),
              document_front_image_file_id: an_instance_of(String),
              document_state: address_data[:state],
              document_number: pii_from_doc[:documentNumber],
              document_issued: Date.parse(pii_from_doc[:issueDate]),
              document_expiration: Date.parse(pii_from_doc[:expirationDate]),
              first_name: pii_from_doc[:firstName],
              last_name: pii_from_doc[:surName],
              date_of_birth: Date.parse(pii_from_doc[:dob]),
              address1: address_data[:physicalAddress],
              address2: address_data[:physicalAddress2],
              city: address_data[:city],
              state: address_data[:state],
              zip: address_data[:zip],
              failure_reason: { unaccepted_id_type: true },
            )

            perform
          end
        end
      end

      context 'Socure returns an error' do
        let(:status) { 'Error' }
        let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
        let(:msg) { 'InternalServerException' }
        let(:socure_response_body) { { status:, referenceId:, msg: } }

        it 'logs the status, reference_id, and message' do
          perform

          expect(fake_analytics).to have_logged_event(
            :idv_socure_verification_data_requested,
            hash_including(
              :vendor_status,
              :reference_id,
              :vendor_status_message,
            ),
          )
        end

        context 'doc escrow is enabled' do
          let(:socure_doc_escrow_enabled) { true }

          it 'stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: false,
              document_back_image_encryption_key: an_instance_of(String),
              document_back_image_file_id: an_instance_of(String),
              document_front_image_encryption_key: an_instance_of(String),
              document_front_image_file_id: an_instance_of(String),
              document_state: nil,
              document_number: nil,
              document_issued: nil,
              document_expiration: nil,
              first_name: nil,
              last_name: nil,
              date_of_birth: nil,
              address1: nil,
              address2: nil,
              city: nil,
              state: nil,
              zip: nil,
              failure_reason: { unaccepted_id_type: true },
            )

            perform
          end
        end
      end

      context 'Pii validation fails' do
        before do
          allow_any_instance_of(Idv::DocPiiStateId).to receive(:zipcode).and_return(:invalid_junk)
        end

        it 'stores a failed result' do
          perform

          document_capture_session.reload
          document_capture_session_result = document_capture_session.load_result
          expect(document_capture_session_result.success).to eq(false)
          expect(document_capture_session_result.doc_auth_success).to eq(true)
          expect(document_capture_session_result.errors).to eq({ pii_validation: 'failed' })
        end

        context 'doc escrow is enabled' do
          let(:socure_doc_escrow_enabled) { true }

          it 'tracks the attempt and stores the images via doc escrow' do
            expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
              success: false,
              document_back_image_encryption_key: an_instance_of(String),
              document_back_image_file_id: an_instance_of(String),
              document_front_image_encryption_key: an_instance_of(String),
              document_front_image_file_id: an_instance_of(String),
              document_state: address_data[:state],
              document_number: pii_from_doc[:documentNumber],
              document_issued: Date.parse(pii_from_doc[:issueDate]),
              document_expiration: Date.parse(pii_from_doc[:expirationDate]),
              first_name: pii_from_doc[:firstName],
              last_name: pii_from_doc[:surName],
              date_of_birth: Date.parse(pii_from_doc[:dob]),
              address1: address_data[:physicalAddress],
              address2: address_data[:physicalAddress2],
              city: address_data[:city],
              state: address_data[:state],
              zip: '10001',
              failure_reason: { zipcode: [:zipcode] },
            )

            perform
          end
        end
      end

      it 'logs an idv_doc_auth_submitted_pii_validation event' do
        perform
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor pii validation',
          hash_including(
            :submit_attempts,
            :remaining_submit_attempts,
          ),
        )
      end

      it 'logs an idv_socure_verification_data_requested event' do
        perform
        expect(fake_analytics).to have_logged_event(
          :idv_socure_verification_data_requested,
          hash_including(
            expected_socure_log.merge({ async: true }),
          ),
        )
      end

      it 'expect log with perform_now to have async eq false' do
        perform_now
        expect(fake_analytics).to have_logged_event(
          :idv_socure_verification_data_requested,
          hash_including(
            expected_socure_log.merge({ async: false }),
          ),
        )
      end

      context 'when the document capture session does not exist' do
        let(:document_capture_session_uuid) { '1234' }

        it 'raises an error and fails to store the result from the Socure DocV request' do
          expect { perform }.to raise_error(
            RuntimeError,
            "DocumentCaptureSession not found: #{document_capture_session_uuid}",
          )
          document_capture_session.reload
          expect(document_capture_session.load_result).to be_nil
          expect(document_capture_session.last_doc_auth_result).to be_nil
        end

        it 'does not track an event' do
          expect(attempts_api_tracker).not_to receive(:idv_document_upload_submitted)

          expect { perform }.to raise_error(
            RuntimeError,
            "DocumentCaptureSession not found: #{document_capture_session_uuid}",
          )
        end
      end
    end

    context 'when we get a non-200 HTTP response back from Socure' do
      %w[400 403 404 500].each do |http_status|
        context "Socure returns HTTP #{http_status} with an error body" do
          let(:status) { 'Error' }
          let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
          let(:msg) { 'InternalServerException' }
          let(:socure_response_body) { { status:, referenceId:, msg: } }

          before do
            stub_request(:post, 'https://example.com/api/3.0/EmailAuthScore')
              .to_return(
                status: http_status,
                headers: {
                  'Content-Type' => 'application/json',
                },
                body: JSON.generate(socure_response_body),
              )
            stub_request(:get, "https://upload.socure.us/api/5.0/documents/#{socure_response_body[:referenceId]}")
              .to_return(
                headers: {
                  'Content-Type' => 'application/zip',
                  'Content-Disposition' => 'attachment; filename=document.zip',
                },
                body: DocAuthImageFixtures.zipped_files(
                  reference_id: socure_response_body[:referenceId],
                  selfie:,
                ).to_s,
              )
          end

          it 'logs the status, reference_id, and message' do
            perform

            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
              hash_including(
                {
                  vendor_status: 'Error',
                  reference_id: referenceId,
                  vendor_status_message: msg,
                },
              ),
            )
          end

          context 'doc escrow is enabled' do
            let(:socure_doc_escrow_enabled) { true }
            it 'tracks the attempt and stores the images via doc escrow' do
              expect(attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
                success: false,
                document_state: nil,
                document_number: nil,
                document_issued: nil,
                document_expiration: nil,
                first_name: nil,
                last_name: nil,
                date_of_birth: nil,
                address1: nil,
                address2: nil,
                city: nil,
                state: nil,
                zip: nil,
                failure_reason: { network: true },
              )

              perform
            end
          end
        end

        context "Socure returns HTTP #{http_status} with no error body" do
          before do
            stub_request(:post, 'https://example.com/api/3.0/EmailAuthScore')
              .to_return(status: http_status)
          end

          it 'logs the event' do
            perform

            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
            )
          end
        end
      end
    end
  end
end
