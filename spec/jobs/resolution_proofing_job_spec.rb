require 'rails_helper'

RSpec.describe ResolutionProofingJob, type: :job do
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,
    )
  end
  let(:document_capture_session) do
    DocumentCaptureSession.new(result_id: SecureRandom.hex, uuid: SecureRandom.uuid)
  end
  let(:trace_id) { SecureRandom.uuid }
  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) { create(:service_provider, app_id: 'fake-app-id') }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:proofing_device_profiling) { :enabled }
  let(:lexisnexis_threatmetrix_mock_enabled) { false }
  let(:ipp_enrollment_in_progress) { false }
  let(:proofing_components) { nil }

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling)
      .and_return(proofing_device_profiling)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
      .and_return(lexisnexis_threatmetrix_mock_enabled)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_base_url)
      .and_return('https://www.example.com')
    allow(IdentityConfig.store).to receive(:idv_resolution_default_vendor)
      .and_return(:instant_verify)
  end

  describe '#perform' do
    let(:instance) { ResolutionProofingJob.new }

    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user.id,
        service_provider_issuer: service_provider.issuer,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        proofing_components: proofing_components,
      )
    end

    context 'ssn_is_unique attribute' do
      context 'when the SSN is unique' do
        it 'sets ssn_is_unique: true on the result' do
          stub_vendor_requests
          perform

          result = document_capture_session.load_proofing_result[:result]
          expect(result[:ssn_is_unique]).to eq(true)
        end
      end

      context 'when the SSN is not unique' do
        before do
          create(:profile, pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN)
        end

        it 'sets ssn_is_unique: false on the result' do
          stub_vendor_requests
          perform

          result = document_capture_session.load_proofing_result[:result]
          expect(result[:ssn_is_unique]).to eq(false)
        end
      end
    end

    context 'all of the vendor requests pass' do
      it 'stores a successful result' do
        stub_vendor_requests

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]
        result_context_stages_state_id = result_context_stages[:state_id]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:exception]).to be_nil
        expect(result[:errors].keys).to eq([:'Execute Instant Verify'])
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false
        expect(result[:threatmetrix_review_status]).to eq('pass')

        # result[:context]
        expect(result_context[:should_proof_state_id])

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:vendor_name])
          .to eq('lexisnexis:instant_verify')
        expect(result_context_stages_resolution[:errors]).to include(:'Execute Instant Verify')
        expect(result_context_stages_resolution[:exception]).to eq(nil)
        expect(result_context_stages_resolution[:success]).to eq(true)
        expect(result_context_stages_resolution[:timed_out]).to eq(false)
        expect(result_context_stages_resolution[:transaction_id]).to eq('123456')
        expect(result_context_stages_resolution[:reference]).to eq('Reference1')
        expect(result_context_stages_resolution[:can_pass_with_additional_verification])
          .to eq(false)
        expect(result_context_stages_resolution[:attributes_requiring_additional_verification])
          .to eq([])

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
        expect(result_context_stages_state_id[:errors]).to eq({})
        expect(result_context_stages_state_id[:exception]).to eq(nil)
        expect(result_context_stages_state_id[:success]).to eq(true)
        expect(result_context_stages_state_id[:timed_out]).to eq(false)
        expect(result_context_stages_state_id[:transaction_id]).to eq('1234-abcd-efgh')
        expect(result_context_stages_state_id[:verified_attributes]).to match_array(
          %w[
            address
            state_id_expiration
            state_id_issued
            state_id_number
            id_doc_type
            dob
            last_name
            first_name
            middle_name
            name_suffix
            height
            sex
            weight
            eye_color
          ],
        )

        # result[:context][:stages][:threatmetrix]
        expect(result_context_stages_threatmetrix[:client]).to eq('lexisnexis')
        expect(result_context_stages_threatmetrix[:errors]).to eq({})
        expect(result_context_stages_threatmetrix[:exception]).to eq(nil)
        expect(result_context_stages_threatmetrix[:success]).to eq(true)
        expect(result_context_stages_threatmetrix[:timed_out]).to eq(false)
        expect(result_context_stages_threatmetrix[:transaction_id]).to eq('1234')
        expect(result_context_stages_threatmetrix[:review_status]).to eq('pass')
        expect(result_context_stages_threatmetrix[:response_body]).to eq(
          JSON.parse(LexisNexisFixtures.ddp_success_redacted_response_json, symbolize_names: true),
        )
      end
    end

    context 'with a failed InstantVerify result' do
      it 'stores an unsuccessful result' do
        stub_vendor_requests(
          instant_verify_response:
            LexisNexisFixtures.instant_verify_identity_not_found_response_json,
        )

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]

        expect(result[:success]).to be false
        expect(result[:errors].keys).to eq([:base, :'Execute Instant Verify'])
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:success]).to eq(false)
        expect(result_context_stages_resolution[:errors]).to include(
          :base,
          :'Execute Instant Verify',
        )
        expect(result_context_stages_resolution[:exception]).to eq(nil)
        expect(result_context_stages_resolution[:timed_out]).to eq(false)
      end
    end

    context 'with a InstantVerify result with failed attributes covered by the AAMVA result' do
      it 'stores a successful result' do
        stub_vendor_requests(
          instant_verify_response: LexisNexisFixtures.instant_verify_address_fail_response_json,
          aamva_response: AamvaFixtures.verification_response,
        )

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]
        result_context_stages_state_id = result_context_stages[:state_id]

        expect(result[:success]).to be true
        expect(result[:errors].keys).to eq([:base, :'Execute Instant Verify'])
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:vendor_name])
          .to eq('lexisnexis:instant_verify')
        expect(result_context_stages_resolution[:success]).to eq(false)
        expect(result_context_stages_resolution[:can_pass_with_additional_verification])
          .to eq(true)
        expect(result_context_stages_resolution[:attributes_requiring_additional_verification])
          .to eq(['address'])

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
        expect(result_context_stages_state_id[:success]).to eq(true)
        expect(result_context_stages_state_id[:verified_attributes]).to match_array(
          %w[
            address
            state_id_expiration
            state_id_issued
            state_id_number
            id_doc_type
            dob
            last_name
            first_name
            middle_name
            name_suffix
            height
            sex
            weight
            eye_color
          ],
        )
      end
    end

    context 'with a InstantVerify result with failed attributes that cannot be covered by AAMVA' do
      it 'stores an unsuccessful result and does not make an AAMVA request' do
        stub_vendor_requests(
          instant_verify_response:
            LexisNexisFixtures.instant_verify_identity_not_found_response_json,
        )

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]
        result_context_stages_state_id = result_context_stages[:state_id]

        expect(result[:success]).to be false
        expect(result[:errors].keys).to eq([:base, :'Execute Instant Verify'])
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:vendor_name])
          .to eq('lexisnexis:instant_verify')
        expect(result_context_stages_resolution[:success]).to eq(false)
        expect(result_context_stages_resolution[:can_pass_with_additional_verification])
          .to eq(true)
        expect(result_context_stages_resolution[:attributes_requiring_additional_verification])
          .to match(['address', 'dead', 'dob', 'ssn'])

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('UnsupportedJurisdiction')
        expect(result_context_stages_state_id[:success]).to eq(true)

        expect(@aamva_stub).to_not have_been_requested
      end
    end

    context 'with a failed AAMVA result' do
      it 'stores an unsuccessful result' do
        stub_vendor_requests(aamva_response: AamvaFixtures.verification_response_namespaced_failure)

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_state_id = result_context_stages[:state_id]

        expect(result[:success]).to be false
        expect(result[:errors]).to include(
          :state_id_number, :id_doc_type, :dob, :last_name, :first_name, :address1, :address2,
          :city, :state, :zipcode
        )
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
        expect(result_context_stages_state_id[:success]).to eq(false)
        expect(result_context_stages_state_id[:errors]).to include(
          :state_id_number, :id_doc_type, :dob, :last_name, :first_name, :address1, :address2,
          :city, :state, :zipcode
        )
        expect(result_context_stages_state_id[:exception]).to eq(nil)

        expect(result_context_stages_state_id[:timed_out]).to eq(false)
      end
    end

    context 'in a state where AAMVA is not supported' do
      let(:pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(state_id_jurisdiction: 'NY')
      end

      it 'does not make an AAMVA request' do
        stub_vendor_requests

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_state_id = result_context_stages[:state_id]

        expect(result[:success]).to be true
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('UnsupportedJurisdiction')
        expect(result_context_stages_state_id[:success]).to eq(true)

        expect(@aamva_stub).to_not have_been_requested
      end
    end

    context 'with threatmetrix disabled' do
      let(:proofing_device_profiling) { :disabled }

      it 'does not make a request to threatmetrix' do
        stub_vendor_requests

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:success]).to be true
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false
        expect(result[:threatmetrix_review_status]).to eq('pass')

        # result[:context][:stages][:threatmetrix]
        expect(result_context_stages_threatmetrix[:success]).to eq(true)
        expect(result_context_stages_threatmetrix[:client]).to eq('tmx_disabled')

        expect(@threatmetrix_stub).to_not have_been_requested
      end
    end

    context "when the user's state ID address does not match their residential address" do
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }
      let(:ipp_enrollment_in_progress) { true }

      let(:residential_address) do
        {
          address1: pii[:address1],
          address2: pii[:address2],
          city: pii[:city],
          state: pii[:state],
          state_id_jurisdiction: pii[:state_id_jurisdiction],
          zipcode: pii[:zipcode],
        }
      end

      let(:identity_doc_address) do
        {
          address1: pii[:identity_doc_address1],
          address2: pii[:identity_doc_address2],
          city: pii[:identity_doc_city],
          state: pii[:identity_doc_address_state],
          state_id_jurisdiction: pii[:state_id_jurisdiction],
          zipcode: pii[:identity_doc_zipcode],
        }
      end

      subject(:perform) do
        instance.perform(
          result_id: document_capture_session.result_id,
          encrypted_arguments: encrypted_arguments,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: threatmetrix_session_id,
          request_ip: request_ip,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        )
      end

      it 'stores a successful result' do
        stub_vendor_requests

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]
        result_context_residential_address = result_context_stages[:residential_address]
        result_context_stages_state_id = result_context_stages[:state_id]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:exception]).to be_nil
        expect(result[:errors].keys).to eq([:"Execute Instant Verify"])
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false

        # result[:context]
        expect(result_context[:should_proof_state_id])

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:vendor_name])
          .to eq('lexisnexis:instant_verify')
        expect(result_context_stages_resolution[:errors]).to include(:"Execute Instant Verify")
        expect(result_context_stages_resolution[:exception]).to eq(nil)
        expect(result_context_stages_resolution[:success]).to eq(true)
        expect(result_context_stages_resolution[:timed_out]).to eq(false)
        expect(result_context_stages_resolution[:transaction_id]).to eq('123456')
        expect(result_context_stages_resolution[:reference]).to eq('Reference1')
        expect(result_context_stages_resolution[:can_pass_with_additional_verification])
          .to eq(false)
        expect(result_context_stages_resolution[:attributes_requiring_additional_verification])
          .to eq([])

        # result[:context][:stages][:residential_address]
        expect(result_context_residential_address[:vendor_name]).to eq('lexisnexis:instant_verify')
        expect(result_context_residential_address[:errors]).to include(:"Execute Instant Verify")
        expect(result_context_residential_address[:exception]).to eq(nil)
        expect(result_context_residential_address[:success]).to eq(true)
        expect(result_context_residential_address[:timed_out]).to eq(false)
        expect(result_context_residential_address[:transaction_id]).to eq('123456')
        expect(result_context_residential_address[:reference]).to eq('Reference1')
        expect(result_context_residential_address[:can_pass_with_additional_verification])
          .to eq(false)
        expect(result_context_residential_address[:attributes_requiring_additional_verification])
          .to eq([])

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
        expect(result_context_stages_state_id[:errors]).to eq({})
        expect(result_context_stages_state_id[:exception]).to eq(nil)
        expect(result_context_stages_state_id[:success]).to eq(true)
        expect(result_context_stages_state_id[:timed_out]).to eq(false)
        expect(result_context_stages_state_id[:transaction_id]).to eq('1234-abcd-efgh')
        expect(result_context_stages_state_id[:verified_attributes]).to match_array(
          %w[
            address
            state_id_expiration
            state_id_issued
            state_id_number
            id_doc_type
            dob
            last_name
            first_name
            middle_name
            name_suffix
            height
            sex
            weight
            eye_color
          ],
        )

        # result[:context][:stages][:threatmetrix]
        expect(result_context_stages_threatmetrix[:client]).to eq('lexisnexis')
        expect(result_context_stages_threatmetrix[:errors]).to eq({})
        expect(result_context_stages_threatmetrix[:exception]).to eq(nil)
        expect(result_context_stages_threatmetrix[:success]).to eq(true)
        expect(result_context_stages_threatmetrix[:timed_out]).to eq(false)
        expect(result_context_stages_threatmetrix[:transaction_id]).to eq('1234')
        expect(result_context_stages_threatmetrix[:review_status]).to eq('pass')
        expect(result_context_stages_threatmetrix[:response_body]).to eq(
          JSON.parse(LexisNexisFixtures.ddp_success_redacted_response_json, symbolize_names: true),
        )
      end
    end

    context 'without a threatmetrix session ID' do
      let(:threatmetrix_session_id) { nil }
      let(:ipp_enrollment_in_progress) { false }

      it 'does not make a request to threatmetrix' do
        stub_vendor_requests

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:success]).to be true
        expect(result[:exception]).to be_nil
        expect(result[:timed_out]).to be false
        expect(result[:threatmetrix_review_status]).to eq('reject')

        # result[:context][:stages][:threatmetrix]
        expect(result_context_stages_threatmetrix[:success]).to eq(false)
        expect(result_context_stages_threatmetrix[:client]).to eq('tmx_session_id_missing')

        expect(@threatmetrix_stub).to_not have_been_requested
      end
    end

    context 'with an invalid threatmetrix review_status value' do
      it 'stores an exception result' do
        stub_vendor_requests(
          threatmetrix_response: LexisNexisFixtures.ddp_unexpected_review_status_response_json,
        )

        perform

        result = document_capture_session.load_proofing_result[:result]
        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:success]).to be false
        expect(result[:exception]).to include(LexisNexisFixtures.ddp_unexpected_review_status)
        expect(result[:timed_out]).to be false
        expect(result[:threatmetrix_review_status]).to be_nil

        expect(result_context_stages_threatmetrix[:exception]).to include(
          LexisNexisFixtures.ddp_unexpected_review_status,
        )
      end
    end

    context 'a stale job' do
      it 'bails and does not do any proofing' do
        stub_vendor_requests

        instance.enqueued_at = 10.minutes.ago

        expect(@aamva_stub).to_not have_been_requested
        expect(@instant_verify_stub).to_not have_been_requested
        expect(@threatmetrix_stub).to_not have_been_requested

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end

    context 'Socure shadow mode test' do
      let(:idv_socure_shadow_mode_enabled_for_docv_users) { false }
      let(:idv_socure_shadow_mode_enabled) { false }
      let(:doc_auth_vendor) { nil }
      let(:in_shadow_mode_ab_test_bucket) { false }

      before do
        allow(IdentityConfig.store).to receive(:idv_socure_shadow_mode_enabled_for_docv_users)
          .and_return(idv_socure_shadow_mode_enabled_for_docv_users)
        allow(IdentityConfig.store).to receive(:idv_socure_shadow_mode_enabled)
          .and_return(idv_socure_shadow_mode_enabled)

        allow(instance).to receive(:shadow_mode_ab_test_bucket) do |user:|
          expect(user).not_to eql(nil)
          if in_shadow_mode_ab_test_bucket
            :socure_shadow_mode_for_non_docv_users
          end
        end

        stub_vendor_requests
      end

      context 'when enabled' do
        let(:idv_socure_shadow_mode_enabled) { true }

        context 'and user is selected in A/B test' do
          let(:in_shadow_mode_ab_test_bucket) { true }

          it 'schedules a SocureShadowModeProofingJob' do
            expect(SocureShadowModeProofingJob).to receive(:perform_later).with(
              user_email: user.email,
              user_uuid: user.uuid,
              document_capture_session_result_id: document_capture_session.result_id,
              encrypted_arguments: satisfy do |ciphertext|
                json = JSON.parse(
                  Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(ciphertext),
                  symbolize_names: true,
                )
                expect(json[:applicant_pii]).to eql(
                  {
                    first_name: 'FAKEY',
                    middle_name: nil,
                    last_name: 'MCFAKERSON',
                    name_suffix: 'JR',
                    address1: '1 FAKE RD',
                    identity_doc_address1: '1 FAKE RD',
                    identity_doc_address2: '',
                    identity_doc_city: 'GREAT FALLS',
                    identity_doc_address_state: 'MT',
                    identity_doc_zipcode: '59010-1234',
                    issuing_country_code: 'US',
                    address2: '',
                    same_address_as_id: 'true',
                    city: 'GREAT FALLS',
                    state: 'MT',
                    zipcode: '59010-1234',
                    dob: '1938-10-06',
                    sex: 'male',
                    height: 72,
                    weight: nil,
                    eye_color: nil,
                    ssn: '900661234',
                    state_id_jurisdiction: 'ND',
                    state_id_expiration: '2099-12-31',
                    state_id_issued: '2019-12-31',
                    state_id_number: '1111111111111',
                    id_doc_type: 'drivers_license',
                  },
                )
              end,
              service_provider_issuer: service_provider.issuer,
            )

            perform
          end

          context 'and shadow mode also enabled for docv users' do
            let(:idv_socure_shadow_mode_enabled_for_docv_users) { true }

            context 'when the user is a docv user' do
              let(:proofing_components) do
                {
                  document_check: Idp::Constants::Vendors::SOCURE,
                }
              end
              it 'only schedules 1 SocureShadowModeProofingJob' do
                expect(SocureShadowModeProofingJob).to receive(:perform_later).once
                perform
              end
            end
          end
        end

        context 'and user is NOT selected in A/B test' do
          let(:in_shadow_mode_ab_test_bucket) { false }

          it 'does not schedule a shadow mode job' do
            expect(SocureShadowModeProofingJob).not_to receive(:perform_later)
            perform
          end

          context 'but shadow mode is enabled for docv users' do
            let(:idv_socure_shadow_mode_enabled_for_docv_users) { true }

            context 'and the user happens to be a docv user' do
              let(:proofing_components) do
                {
                  document_check: Idp::Constants::Vendors::SOCURE,
                }
              end

              it 'schedules a SocureShadowModeProofingJob' do
                expect(SocureShadowModeProofingJob).to receive(:perform_later).once
                perform
              end
            end

            context 'except the user did not use Socure docv' do
              it 'does not schedule a SocureShadowModeProofingJob' do
                expect(SocureShadowModeProofingJob).not_to receive(:perform_later)
                perform
              end
            end
          end
        end
      end

      context 'when disabled' do
        let(:idv_socure_shadow_mode_enabled) { false }

        it 'does not schedule a SocureShadowModeProofingJob' do
          stub_vendor_requests
          expect(SocureShadowModeProofingJob).not_to receive(:perform_later)
          perform
        end

        context 'but the flag to enable shadow mode for docv users was left on' do
          let(:idv_socure_shadow_mode_enabled_for_docv_users) { true }
          context 'when user is a docv user' do
            it 'does not schedule a SocureShadowModeProofingJob' do
              stub_vendor_requests
              expect(SocureShadowModeProofingJob).not_to receive(:perform_later)
              perform
            end
          end
        end
      end
    end

    it 'determines the UUID and UUID prefix and passes it to the downstream proofing vendors' do
      uuid_info = {
        uuid_prefix: service_provider.app_id,
        uuid: user.uuid,
      }

      stub_vendor_requests

      expect_any_instance_of(Proofing::LexisNexis::InstantVerify::Proofer).to receive(:proof)
        .with(hash_including(uuid_info)).and_call_original

      expect_any_instance_of(Proofing::Aamva::Proofer).to receive(:proof).with(
        hash_including(uuid_info),
      ).and_call_original

      perform
    end

    def stub_vendor_requests(
      instant_verify_response: LexisNexisFixtures.instant_verify_success_response_json,
      threatmetrix_response: LexisNexisFixtures.ddp_success_response_json,
      aamva_response: AamvaFixtures.verification_response
    )
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      @instant_verify_stub = stub_instant_verify_request(instant_verify_response)
      @threatmetrix_stub = stub_threatmetrix_request(threatmetrix_response)
      @aamva_stub = stub_aamva_request(aamva_response)
    end

    def stub_instant_verify_request(instant_verify_response)
      instant_verify_url = URI.join(
        IdentityConfig.store.lexisnexis_base_url,
        '/restws/identity/v2/',
        IdentityConfig.store.lexisnexis_account_id + '/',
        IdentityConfig.store.lexisnexis_instant_verify_workflow + '/',
        'conversation',
      )
      stub_request(
        :post,
        instant_verify_url,
      ).to_return(body: instant_verify_response)
    end

    def stub_threatmetrix_request(threatmetrix_response)
      stub_request(
        :post,
        'https://www.example.com/api/session-query',
      ).to_return(body: threatmetrix_response)
    end

    def stub_aamva_request(aamva_response)
      allow(IdentityConfig.store).to receive(:aamva_private_key)
        .and_return(AamvaFixtures.example_config.private_key)
      allow(IdentityConfig.store).to receive(:aamva_public_key)
        .and_return(AamvaFixtures.example_config.public_key)
      stub_request(:post, IdentityConfig.store.aamva_auth_url)
        .to_return(
          { body: AamvaFixtures.security_token_response },
          { body: AamvaFixtures.authentication_token_response },
        )
      stub_request(:post, IdentityConfig.store.aamva_verification_url)
        .to_return(body: aamva_response)
    end
  end
end
