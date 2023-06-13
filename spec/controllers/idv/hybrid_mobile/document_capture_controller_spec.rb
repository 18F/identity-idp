require 'rails_helper'

RSpec.describe Idv::HybridMobile::DocumentCaptureController do
  include IdvHelper

  let(:user) { create(:user) }

  let!(:document_capture_session) do
    DocumentCaptureSession.create!(
      user: user,
      requested_at: document_capture_session_requested_at,
    )
  end

  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  let(:document_capture_session_requested_at) { Time.zone.now }

  before do
    stub_analytics
    stub_attempts_tracker

    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid
  end

  describe 'before_actions' do
    it 'includes :check_valid_document_capture_session' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end

  describe '#show' do
    context 'with no user id in session' do
      let(:document_capture_session) { nil }
      let(:user) { nil }

      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'with a user id in session' do
      let(:analytics_name) { 'IdV: doc auth document_capture visited' }
      let(:analytics_args) do
        {
          acuant_sdk_upgrade_ab_test_bucket: :default,
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
          irs_reproofing: false,
          step: 'document_capture',
        }
      end

      it 'renders the show template' do
        expect(subject).to receive(:render).with(
          :show,
          locals: hash_including(
            document_capture_session_uuid: document_capture_session_uuid,
          ),
        ).and_call_original

        get :show

        expect(response).to render_template :show
      end

      it 'sends analytics_visited event' do
        get :show

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'updates DocAuthLog document_capture_view_count' do
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { get :show }.to(
          change { doc_auth_log.reload.document_capture_view_count }.from(0).to(1),
        )
      end

      context 'with expired DocumentCaptureSession' do
        let(:document_capture_session_requested_at) do
          Time.zone.now.advance(
            minutes: IdentityConfig.store.doc_capture_request_valid_for_minutes * -2,
          )
        end
        it 'redirects to root' do
          get :show
          expect(response).to redirect_to(root_url)
        end
      end
    end
  end

  describe '#update' do
    before do
      allow_any_instance_of(DocumentCaptureSession).to receive(:load_result).and_return(
        DocumentCaptureSessionResult.new(
          id: 1234,
          success: true,
          pii: {
            state: 'WA',
          },
          attention_with_barcode: true,
        ),
      )
    end

    context 'with no user id in session' do
      let(:user) { nil }
      let(:document_capture_session) { nil }
      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'with a user id in session' do
      let(:analytics_name) { 'IdV: doc auth document_capture submitted' }
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
          irs_reproofing: false,
          step: 'document_capture',
          acuant_sdk_upgrade_ab_test_bucket: :default,
        }
      end

      before do
        session[:doc_capture_user_id] = user.id
      end

      it 'tracks expected events' do
        get :show
        put :update

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'does not raise an exception when stored_result is nil' do
        allow(subject).to receive(:stored_result).and_return(nil)

        put :update
      end

      it 'redirects to CaptureComplete step' do
        put :update
        expect(response).to redirect_to idv_hybrid_mobile_capture_complete_url
      end
    end
  end

  describe '#extra_view_variables' do
    subject(:extra_view_variables) { controller.extra_view_variables }

    it 'includes acuant a/b testing vars' do
      expect(controller).to receive(:acuant_sdk_upgrade_a_b_testing_variables).and_call_original
      controller.extra_view_variables
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
end
