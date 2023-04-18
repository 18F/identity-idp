require 'rails_helper'

describe Idv::HybridMobile::DocumentCaptureController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:feature_flag_enabled) { true }

  before do
    stub_analytics
    stub_attempts_tracker

    allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
      and_return(feature_flag_enabled)
  end

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end

  describe '#show' do
    context 'with no user id in session' do
      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'with a user id in session' do
      before do
        mock_session(user.id)

        allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).and_return(true)

        # Pretend we're running in AWS so that we get S3 upload URLs generated
        allow(Identity::Hostdata::EC2).to receive(:load).
          and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
      end

      context 'feature flag disabled' do
        let(:feature_flag_enabled) { false }
        it 'returns a 404' do
          get :show
          expect(response.status).to eql(404)
        end
      end

      it 'renders the document_capture template' do
        expect(subject).to receive(:render).with(
          template: 'layouts/flow_step',
          locals: hash_including(
            :back_image_upload_url,
            :front_image_upload_url,
            :flow_session,
            step_template: 'idv/capture_doc/document_capture',
            flow_namespace: 'idv',
          ),
        ).and_call_original

        get :show
      end

      it 'tracks expected events' do
        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth document_capture visited',
          hash_including(
            flow_path: 'hybrid',
            step: 'document_capture',
            step_count: 1,
            analytics_id: 'Doc Auth',
            # "irs_reproofing": false,
            # "acuant_sdk_upgrade_ab_test_bucket": "default"
          ),
        )
      end

      it 'tracks step count' do
        get :show
        get :show
        expect(@analytics).to have_logged_event(
          'IdV: doc auth document_capture visited',
          hash_including(step_count: 2),
        )
      end
    end
  end

  describe '#update' do
    it 'tracks expected events' do
      # "name": "IdV: doc auth image upload form submitted",
      # "properties": {
      #   "event_properties": {
      #     "success": true,
      #     "errors": {},
      #     "attempts": 1,
      #     "remaining_attempts": 4,
      #     "flow_path": "hybrid"
      #   }

      # "name": "IdV: doc auth image upload vendor submitted",
      # "properties": {
      #   "event_properties": {
      #     "success": false,
      #     "errors": {
      #       "general": [
      #         "We couldn’t read the control number barcode. Try taking new pictures."
      #       ],
      #       "back": [
      #         "Please add a new image"
      #       ],
      #       "hints": true
      #     },
      #     "exception": null,
      #     "billed": true,
      #     "doc_auth_result": "Caution",
      #     "state": "NY",
      #     "state_id_type": null,
      #     "async": false,
      #     "attempts": 1,
      #     "remaining_attempts": 4,
      #     "client_image_metrics": {
      #       "front": {
      #         "width": null,
      #         "height": null,
      #         "mimeType": "application/x-yaml",
      #         "source": "upload",
      #         "size": 394,
      #         "attempt": 1
      #       },
      #       "back": {
      #         "width": null,
      #         "height": null,
      #         "mimeType": "application/x-yaml",
      #         "source": "upload",
      #         "size": 394,
      #         "attempt": 1
      #       }
      #     },
      #     "flow_path": "hybrid",
      #     "attention_with_barcode": false
      #   }
    end
  end

  describe '#extra_view_variables' do
    subject(:extra_view_variables) { controller.extra_view_variables }

    describe 'acuant a/b testing' do
      let(:default_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_default }
      let(:alternate_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_alternate }

      let(:document_capture_session_uuid) { SecureRandom.uuid }

      before do
        session[:document_capture_session_uuid] = document_capture_session_uuid
      end

      context 'with acuant sdk upgrade A/B testing disabled' do
        before do
          allow(IdentityConfig.store).
            to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
            and_return(false)
        end

        context 'and A/B test specifies the older acuant version' do
          before do
            stub_const(
              'AbTests::ACUANT_SDK',
              FakeAbTestBucket.new.tap { |ab| ab.assign(document_capture_session_uuid => 0) },
            )
          end

          it 'passes correct variables and acuant version when older is specified' do
            expect(extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(false)
            expect(extra_view_variables[:use_alternate_sdk]).to eq(false)
            expect(extra_view_variables[:acuant_version]).to eq(default_sdk_version)
          end
        end
      end

      context 'with acuant sdk upgrade A/B testing enabled' do
        before do
          allow(IdentityConfig.store).
            to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
            and_return(true)
        end

        context 'and A/B test specifies the newer acuant version' do
          before do
            stub_const(
              'AbTests::ACUANT_SDK',
              FakeAbTestBucket.new.tap do |ab|
                ab.assign(document_capture_session_uuid => :use_alternate_sdk)
              end,
            )
          end

          it 'passes correct variables and acuant version when newer is specified' do
            expect(extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
            expect(extra_view_variables[:use_alternate_sdk]).to eq(true)
            expect(extra_view_variables[:acuant_version]).to eq(alternate_sdk_version)
          end
        end

        context 'and A/B test specifies the older acuant version' do
          before do
            stub_const(
              'AbTests::ACUANT_SDK',
              FakeAbTestBucket.new.tap { |ab| ab.assign(document_capture_session_uuid => 0) },
            )
          end

          it 'passes correct variables and acuant version when older is specified' do
            expect(extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
            expect(extra_view_variables[:use_alternate_sdk]).to eq(false)
            expect(extra_view_variables[:acuant_version]).to eq(default_sdk_version)
          end
        end
      end
    end

    describe 'in-person CTA variant A/B testing' do
      let(:session_uuid) { SecureRandom.uuid }
      let(:testing_enabled) { nil }
      let(:active_variant) { nil }

      before do
        allow(IdentityConfig.store).
          to receive(:in_person_cta_variant_testing_enabled).
          and_return(testing_enabled)

        session[:document_capture_session_uuid] = session_uuid

        stub_const(
          'AbTests::IN_PERSON_CTA',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => active_variant) },
        )
      end

      context 'with in-person CTA variant A/B testing disabled' do
        let(:testing_enabled) { false }

        context 'and A/B test specifies variant a' do
          let(:active_variant) { :in_person_variant_a }

          it 'passes the correct variables' do
            expect(
              extra_view_variables[:in_person_cta_variant_testing_enabled],
            ).to eq(false)
            expect(
              extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_a)
          end
        end
      end

      describe 'with in-person CTA variant A/B testing enabled' do
        let(:testing_enabled) { true }

        context 'and A/B test specifies variant a' do
          let(:active_variant) { :in_person_variant_a }

          it 'passes the expected variables' do
            expect(extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(
              extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_a)
          end
        end

        context 'and A/B test specifies variant b' do
          let(:active_variant) { :in_person_variant_b }

          it 'passes the expected variables' do
            expect(extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(
              extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_b)
          end
        end

        context 'and A/B test specifies variant c' do
          let(:active_variant) { :in_person_variant_c }

          it 'passes the expected variables' do
            expect(extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(extra_view_variables[:in_person_cta_variant_active]).to eq(:in_person_variant_c)
          end
        end
      end
    end
  end

  def mock_session(user_id)
    session[:doc_capture_user_id] = user_id
  end
end
