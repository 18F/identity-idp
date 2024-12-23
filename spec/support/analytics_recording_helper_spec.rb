require 'rails_helper'

RSpec.describe AnalyticsRecordingHelper do
  let(:helper) do
    Class.new do
      include AnalyticsRecordingHelper
    end.new
  end

  describe '#included' do
    it 'calls around when available' do
      c = Class.new do
        def self.around(&_block)
          @around_called = true
        end

        def self.around_called = @around_called

        include AnalyticsRecordingHelper
      end

      expect(c.around_called).to eql(true)
    end

    it 'does not call around when not available' do
      c = Class.new do
        include AnalyticsRecordingHelper
      end

      expect { c.new }.not_to raise_error
    end
  end

  describe '#normalize_analytics_event_for_comparison' do
    subject(:normalized_event) do
      helper.normalize_analytics_event_for_comparison(raw_event)
    end

    context 'with a "Sign in page visited" event' do
      # rubocop:disable Layout/LineLength
      let(:raw_event) do
        { name: 'Sign in page visited',
          properties: {
            event_properties: {},
            new_event: true,
            path: '/',
            service_provider: nil,
            session_duration: 0.390307,
            user_id: 'anonymous-uuid',
            locale: :en,
            user_ip: '127.0.0.1',
            hostname: '127.0.0.1',
            pid: 35171,
            trace_id: nil,
            git_sha: 'abcdef',
            git_branch: 'main',
            user_agent: 'Mozilla/5.0 (Linux; U; Android 9; en-US; Fridge-Model/1234) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36 SmartFridgeBrowser/1.0',
            browser_name: 'Chrome',
            browser_version: 'Unknown',
            browser_platform_name: 'Unknown',
            browser_platform_version: 'Unknown',
            browser_device_name: 'Unknown',
            browser_mobile: false,
            browser_bot: false,
          } }
      end
      # rubocop:enable Layout/LineLength

      it 'normalizes' do
        expect(normalized_event).to eql(
          {
            name: 'Sign in page visited',
            properties: {
              event_properties: {},
              new_event: true,
              path: '/',
              user_id: 'anonymous-uuid',
              locale: 'en',
            },
          },
        )
      end
    end

    context 'with a "User Registration: Email Submitted" event' do
      let(:raw_event) do
        {
          'name' => 'User Registration: Email Submitted',
          'properties' => {
            'event_properties' => {
              'success' => true,
              'rate_limited' => false,
              'errors' => {},
              'email_already_exists' => false,
              'domain_name' => 'stanton-langosh.example',
              'email_language' => 'en',
            },
            'new_event' => true,
            'path' => '/sign_up/enter_email',
            'service_provider' => 'urn:gov:gsa:openidconnect:sp:server',
            'user_id' => 'e098bd5a-5c6a-4889-91b4-98cf26972918',
            'locale' => 'en',
            'sp_request' => {
              'component_values' => { 'urn:acr.login.gov:verified' => true },
              'component_separator' => ' ',
              'aal2' => true,
              'identity_proofing' => true,
              'component_names' => ['urn:acr.login.gov:verified'],
            },
          },
        }
      end

      it 'normalizes' do
        expect(normalized_event).to eql(
          {
            name: 'User Registration: Email Submitted',
            properties: {
              event_properties: {
                domain_name: 'domain_name:1',
                email_already_exists: false,
                email_language: 'en',
                errors: {},
                rate_limited: false,
                success: true,
              },
              locale: 'en',
              new_event: true,
              path: '/sign_up/enter_email',
              service_provider: 'urn:gov:gsa:openidconnect:sp:server',
              sp_request: {
                aal2: true,
                component_names: ['urn:acr.login.gov:verified'],
                component_separator: ' ',
                component_values: { "urn:acr.login.gov:verified": true },
                identity_proofing: true,
              },
              user_id: 'uuid:1',
            },
          },
        )
      end
    end

    context 'with "IdV: doc auth image upload vendor submitted" event' do
      let(:raw_event) do
        {
          'name' => 'IdV: doc auth image upload vendor submitted',
          'properties' => {
            'event_properties' => {
              'async' => false,
              'attention_with_barcode' => false,
              'back_image_fingerprint' => 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
              'billed' => true,
              'birth_year' => 1938,
              'client_image_metrics' => {
                'back' => {
                  'acuantCaptureMode' => nil,
                  'captureAttempts' => 1,
                  'failedImageResubmission' => false,
                  'fileName' => 'logo.png',
                  'fingerprint' => 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                  'height' => 38,
                  'liveness_checking_required' => false,
                  'mimeType' => 'image/png',
                  'selfie_attempts' => 0,
                  'size' => 3694,
                  'source' => 'upload',
                  'width' => 284,
                },
                'front' => {
                  'acuantCaptureMode' => nil,
                  'captureAttempts' => 1,
                  'failedImageResubmission' => false,
                  'fileName' => 'logo.png',
                  'fingerprint' => 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                  'height' => 38,
                  'liveness_checking_required' => false,
                  'mimeType' => 'image/png',
                  'selfie_attempts' => 0,
                  'size' => 3694,
                  'source' => 'upload',
                  'width' => 284,
                },
              },
              'doc_auth_result' => 'Passed',
              'doc_auth_success' => true,
              'doc_type_supported' => true,
              'errors' => {},
              'flow_path' => 'standard',
              'front_image_fingerprint' => 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
              'issue_year' => 2019,
              'liveness_checking_required' => false,
              'remaining_submit_attempts' => 3,
              'selfie_live' => true,
              'selfie_quality_good' => true,
              'selfie_status' => 'not_processed',
              'state' => 'MT',
              'state_id_type' => 'drivers_license',
              'submit_attempts' => 1,
              'success' => true,
              'vendor_request_time_in_ms' => '0ish',
              'workflow' => 'test_non_liveness_workflow',
              'zip_code' => '59010',
            },
            'locale' => 'en',
            'new_event' => true,
            'path' => '/api/verify/images',
            'service_provider' => 'urn:gov:gsa:openidconnect:sp:server',
            'sp_request' => {
              'aal2' => true,
              'component_names' => ['urn:acr.login.gov:verified'],
              'component_separator' => ' ',
              'component_values' => { 'urn:acr.login.gov:verified' => true },
              'identity_proofing' => true,
            },
            'user_id' => 'e098bd5a-5c6a-4889-91b4-98cf26972918',
          },
        }
      end

      it 'normalizes' do
        expect(normalized_event).to eql(
          {
            name: 'IdV: doc auth image upload vendor submitted',
            properties: {
              event_properties: {
                async: false,
                attention_with_barcode: false,
                back_image_fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                billed: true,
                birth_year: 1938,
                client_image_metrics: {
                  back: {
                    captureAttempts: 1,
                    failedImageResubmission: false,
                    fileName: 'logo.png',
                    fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                    height: 38,
                    liveness_checking_required: false,
                    mimeType: 'image/png',
                    selfie_attempts: 0,
                    size: 3694,
                    source: 'upload',
                    width: 284,
                  },
                  front: {
                    captureAttempts: 1,
                    failedImageResubmission: false,
                    fileName: 'logo.png',
                    fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                    height: 38,
                    liveness_checking_required: false,
                    mimeType: 'image/png',
                    selfie_attempts: 0,
                    size: 3694,
                    source: 'upload',
                    width: 284,
                  },
                },
                doc_auth_result: 'Passed',
                doc_auth_success: true,
                doc_type_supported: true,
                errors: {},
                flow_path: 'standard',
                front_image_fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q',
                issue_year: 2019,
                liveness_checking_required: false,
                remaining_submit_attempts: 3,
                selfie_live: true,
                selfie_quality_good: true,
                selfie_status: 'not_processed',
                state: 'MT',
                state_id_type: 'drivers_license',
                submit_attempts: 1,
                success: true,
                vendor_request_time_in_ms: '0ish',
                workflow: 'test_non_liveness_workflow',
                zip_code: '59010',
              },
              locale: 'en',
              new_event: true,
              path: '/api/verify/images',
              service_provider: 'urn:gov:gsa:openidconnect:sp:server',
              sp_request: {
                aal2: true,
                component_names: ['urn:acr.login.gov:verified'],
                component_separator: ' ',
                component_values: { "urn:acr.login.gov:verified": true },
                identity_proofing: true,
              },
              user_id: 'uuid:1',
            },
          },
        )
      end
    end

    context 'with "IdV: final resolution" event' do
      let(:raw_event) do
        {
          name: 'IdV: final resolution',
          properties: {
            event_properties: {
              success: true,
              fraud_review_pending: false,
              fraud_rejection: false,
              gpo_verification_pending: false,
              in_person_verification_pending: false,
              proofing_components: {
                document_check: 'mock',
                document_type: 'state_id',
                source_check: 'StateIdMock',
                resolution_check: 'lexis_nexis',
                address_check: 'lexis_nexis_address',
                threatmetrix: true,
                threatmetrix_review_status: 'pass',
              },
              active_profile_idv_level: 'legacy_unsupervised',
              profile_history: [
                {
                  id: 'id:1',
                  active: true,
                  idv_level: 'legacy_unsupervised',
                  created_at: '2024-12-20T23:43:25.986Z',
                  verified_at: '2024-12-20T23:43:25.989Z',
                  activated_at: '2024-12-20T23:43:25.989Z',
                },
              ],
              proofing_workflow_time_in_seconds: 10,
            },
            new_event: true,
            path: '/verify/enter_password',
            service_provider: 'urn:gov:gsa:openidconnect:sp:server',
            user_id: 'uuid:1',
            locale: 'en',
            sp_request: {
              component_values: { "urn:acr.login.gov:verified": true },
              component_separator: ' ',
              aal2: true,
              identity_proofing: true,
              component_names: ['urn:acr.login.gov:verified'],
            },
          },
        }
      end

      it 'normalizes' do
        expect(normalized_event).to eql(
          {
            name: 'IdV: final resolution',
            properties: {
              event_properties: {
                active_profile_idv_level: 'legacy_unsupervised',
                fraud_rejection: false,
                fraud_review_pending: false,
                gpo_verification_pending: false,
                in_person_verification_pending: false,
                profile_history: [
                  {
                    active: true,
                    id: 'id:1',
                    idv_level: 'legacy_unsupervised',
                    created_at: '<TIMESTAMP>',
                    verified_at: '<TIMESTAMP>',
                    activated_at: '<TIMESTAMP>',
                  },
                ],
                proofing_components: {
                  address_check: 'lexis_nexis_address',
                  document_check: 'mock',
                  document_type: 'state_id',
                  resolution_check: 'lexis_nexis',
                  source_check: 'StateIdMock',
                  threatmetrix: true,
                  threatmetrix_review_status: 'pass',
                },
                proofing_workflow_time_in_seconds: '0ish',
                success: true,
              },
              locale: 'en',
              new_event: true,
              path: '/verify/enter_password',
              service_provider: 'urn:gov:gsa:openidconnect:sp:server',
              sp_request: {
                aal2: true,
                component_names: ['urn:acr.login.gov:verified'],
                component_separator: ' ',
                component_values: { "urn:acr.login.gov:verified": true },
                identity_proofing: true,
              },
              user_id: 'uuid:1',
            },
          },
        )
      end
    end

    context 'with "Return to SP: Cancelled" event' do
      let(:raw_event) do
        {
          name: 'Return to SP: Cancelled',
          properties: {
            event_properties: {
              redirect_url: 'http://localhost:7654/auth/result?error=access_denied&state=a8afc3c63dc6b345a3893e38bc99946f',
              step: 'verify_address',
              location: 'come_back_later',
            },
            new_event: true,
            path: '/redirect/return_to_sp/cancel',
            service_provider: 'urn:gov:gsa:openidconnect:sp:server',
            user_id: 'fd5bb94d-4972-4d3f-8b26-662402566109',
            locale: 'en',
            sp_request: {
              component_values: { "urn:acr.login.gov:verified": true },
              component_separator: ' ',
              aal2: true,
              identity_proofing: true,
              component_names: ['urn:acr.login.gov:verified'],
            },
          },
        }
      end
      it 'normalizes' do
        expect(normalized_event).to eql(
          {
            name: 'Return to SP: Cancelled',
            properties: {
              event_properties: {
                location: 'come_back_later',
                redirect_url: 'url_with_state:1',
                step: 'verify_address',
              },
              locale: 'en',
              new_event: true,
              path: '/redirect/return_to_sp/cancel',
              service_provider: 'urn:gov:gsa:openidconnect:sp:server',
              sp_request: {
                aal2: true,
                component_names: ['urn:acr.login.gov:verified'],
                component_separator: ' ',
                component_values: { "urn:acr.login.gov:verified": true },
                identity_proofing: true,
              },
              user_id: 'uuid:1',
            },

          },
        )
      end
    end
  end

  describe '#normalize_part_of_analytics_event' do
    let(:raw_value) do
      nil
    end

    subject(:normalized_value) do
      helper.normalize_part_of_analytics_event(raw_value)
    end

    context 'string' do
      let(:raw_value) { 'foo' }
      it 'leaves input alone' do
        expect(normalized_value).to eql(raw_value)
      end
    end

    context 'number' do
      let(:raw_value) { 42 }
      it 'leaves input alone' do
        expect(normalized_value).to eql(raw_value)
      end
    end

    context 'Symbol' do
      let(:raw_value) { :foo }
      it 'normalizes to string' do
        expect(normalized_value).to eql('foo')
      end
    end

    context 'Hash' do
      let(:raw_value) do
        {
          'foo' => 1234,
          'bar' => 5678,
          'another_hash' => {
            'baz' => 90,
          },
        }
      end

      it 'symbolizes keys... deeply' do
        expect(normalized_value).to eql(
          {
            foo: 1234,
            bar: 5678,
            another_hash: {
              baz: 90,
            },
          },
        )
      end

      context 'with nil values' do
        let(:raw_value) do
          {
            foo: 1234,
            bar: nil,
          }
        end
        it 'removes keys with nil values' do
          expect(normalized_value).to eql(
            {
              foo: 1234,
            },
          )
        end
      end

      context 'with keys that look like database ids' do
        let(:raw_value) do
          {
            email_address_id: 1234,
          }
        end
        it 'tokenizes them' do
          expect(normalized_value).to eql(
            {
              email_address_id: 'email_address_id:1',
            },
          )
        end

        context 'and the key is literally just "id"' do
          let(:raw_value) do
            {
              id: 1234,
            }
          end
          it 'tokenizes them' do
            expect(normalized_value).to eql(
              {
                id: 'id:1',
              },
            )
          end
        end
      end

      context 'with values that look like SHA256 hashes' do
        let(:raw_value) do
          {
            my_key: '6f024c51ca5d0b6568919e134353aaf1398ff090c92f6173f5ce0315fa266b93',
            my_other_key: 'ab2dfa9bfda582a25d9b24cdec1a9363fdcf2f7364fed01a9fdaa03ebf02bb9f',
          }
        end
        it 'tokenizes' do
          expect(normalized_value).to eql(
            { my_key: 'sha_256_hash:1',
              my_other_key: 'sha_256_hash:2' },
          )
        end
      end

      context 'with values that look like urls with random state variables' do
        let(:raw_value) do
          'http://localhost:1234/auth/result?error=access_denied&state=a8afc3c63dc6b345a3893e38bc99946f'
        end
        it 'tokenizes' do
          expect(normalized_value).to eql(
            'url_with_state:1',
          )
        end
      end

      context 'with values the look like ISO 8601 timestamps' do
        let(:raw_value) do
          {
            active: true,
            activated_at: '2024-12-20T23:35:53.879Z',
            created_at: '2024-12-20T23:35:53.875Z',
            verified_at: '2024-12-20T23:35:53.879Z',
          }
        end
        it 'removes the timestamps' do
          expect(normalized_value).to eql(
            {
              active: true,
              activated_at: '<TIMESTAMP>',
              created_at: '<TIMESTAMP>',
              verified_at: '<TIMESTAMP>',
            },
          )
        end
      end

      context 'with values that look like UNIX timestamps' do
        let(:raw_value) do
          {
            created_at: '1734986743624',
          }
        end
        it 'normalizes to just <UNIX TIMESTAMP>' do
          expect(normalized_value).to eql(
            {
              created_at: '<UNIX TIMESTAMP>',
            },
          )
        end
      end
    end
  end
end
