require 'rails_helper'

RSpec.describe 'IdvStepConcern' do
  include FlowPolicyHelper

  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end

  idv_step_controller_class = Class.new(ApplicationController) do
    def self.name
      'AnonymousController'
    end

    include IdvStepConcern

    def show
      render plain: 'Hello'
    end
  end

  describe 'before_actions' do
    it 'includes handle_fraud' do
      expect(idv_step_controller_class).to have_actions(
        :before,
        :handle_fraud,
      )
    end

    it 'includes check_for_mail_only_outage before_action' do
      expect(idv_step_controller_class).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end
  end

  describe '#confirm_hybrid_handoff_needed' do
    controller(idv_step_controller_class) do
      before_action :confirm_hybrid_handoff_needed
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'redo specified' do
      it 'sets flag in idv_session' do
        expect { get :show, params: { redo: true } }.to change {
                                                          idv_session.redo_document_capture
                                                        }.from(nil).to(true)
      end

      it 'does not redirect' do
        get :show, params: { redo: true }
        expect(response).to have_http_status(200)
      end
    end

    context 'document capture complete' do
      before do
        idv_session.pii_from_doc = { first_name: 'Susan' }
      end

      it 'allows the back button and stays on page' do
        get :show
        expect(response).to have_http_status(200)
      end

      context 'and redo specified' do
        it 'does not redirect' do
          get :show, params: { redo: true }
          expect(response).to have_http_status(200)
        end
      end
    end

    context 'previously skipped hybrid handoff' do
      before do
        idv_session.skip_hybrid_handoff = true
        get :show
      end

      it 'sets flow_path to standard' do
        expect(idv_session.flow_path).to eql('standard')
      end

      it 'redirects to document capture' do
        expect(response).to redirect_to(idv_document_capture_url)
      end
    end

    context 'hybrid flow not available' do
      before do
        allow(FeatureManagement).to receive(:idv_allow_hybrid_flow?).and_return(false)
        get :show
      end

      it 'sets flow_path to standard' do
        expect(idv_session.flow_path).to eql('standard')
      end

      it 'redirects to document capture' do
        expect(response).to redirect_to(idv_document_capture_url)
      end
    end
  end

  describe '#confirm_idv_needed' do
    controller(idv_step_controller_class) do
      before_action :confirm_idv_needed
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'user has active profile' do
      before do
        allow(user).to receive(:active_profile).and_return(Profile.new)
        allow(subject).to receive(:current_user).and_return(user)
      end

      context 'and user has not yet acknowledged personal key' do
        before do
          idv_session.personal_key = 'ABCD-1234'
        end
        it 'does not redirect' do
          get :show
          expect(response).not_to redirect_to idv_activated_url
        end

        context 'but they do not have a personal key to acknowledge' do
          before do
            idv_session.personal_key = nil
          end
          it 'redirects to activated page' do
            get :show
            expect(response).to redirect_to idv_activated_url
          end
        end
      end

      context 'and user has acknowledged personal key' do
        before do
          idv_session.acknowledge_personal_key!
        end
        it 'redirects to activated page' do
          get :show

          expect(response).to redirect_to idv_activated_url
        end
      end
    end

    context 'user does not have active profile' do
      before do
        allow(subject).to receive(:current_user).and_return(user)
      end

      it 'does not redirect to activated page' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_activated_url
        expect(response.status).to eq 200
      end
    end
  end

  describe '#confirm_letter_recently_enqueued' do
    controller(idv_step_controller_class) do
      before_action :confirm_letter_recently_enqueued
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'letter was not recently enqueued' do
      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_letter_enqueued_url
        expect(response.status).to eq 200
      end
    end

    context 'letter was recently enqueued' do
      let(:user) { create(:user, :with_pending_gpo_profile, :fully_registered) }

      it 'redirects to letter enqueued page' do
        idv_session.address_verification_mechanism = 'gpo'

        get :show

        expect(response).to redirect_to idv_letter_enqueued_url
      end
    end
  end

  describe '#confirm_no_pending_in_person_enrollment' do
    controller(idv_step_controller_class) do
      before_action :confirm_no_pending_in_person_enrollment
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'without pending in person enrollment' do
      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_in_person_ready_to_verify_url
        expect(response.status).to eq 200
      end
    end

    context 'with pending in person enrollment' do
      let(:user) { create(:user, :with_pending_in_person_enrollment, :fully_registered) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'redirects to in person ready to verify page' do
        get :show

        expect(response).to redirect_to idv_in_person_ready_to_verify_url
      end
    end
  end

  describe '#confirm_no_pending_gpo_profile' do
    controller(idv_step_controller_class) do
      before_action :confirm_no_pending_gpo_profile
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'without pending gpo profile' do
      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_verify_by_mail_enter_code_url
        expect(response.status).to eq 200
      end
    end

    context 'with pending gpo profile' do
      let(:user) { create(:user, :with_pending_gpo_profile, :fully_registered) }

      it 'redirects to enter your code page' do
        get :show

        expect(response).to redirect_to idv_verify_by_mail_enter_code_url
      end
    end
  end

  describe 'FlowPolicy helper methods' do
    controller(idv_step_controller_class) do
    end

    let(:flow_policy) { Idv::FlowPolicy.new(idv_session: idv_session, user: user) }
    before do
      sign_in(user)
      expect(Idv::FlowPolicy).to receive(:new).and_return(flow_policy)
    end

    describe '#confirm_step_allowed and #url_for_latest_step' do
      let(:controller_allowed) { false }
      controller(idv_step_controller_class) do
        before_action :confirm_step_allowed

        def name
          'idv/idv_step_controller'
        end
      end

      before do
        routes.draw do
          get 'show' => 'anonymous#show'
        end
      end

      it 'redirects if the step is not allowed' do
        step_info = Idv::StepInfo.new(
          key: :idv_step_controller,
          controller: controller,
          next_steps: [:agreement],
          preconditions: ->(idv_session:, user:) { false },
          undo_step: ->(idv_session:, user:) {},
        )
        expect(flow_policy).to receive(:controller_allowed?).
          with(controller: controller.class).and_return(false)
        expect(flow_policy).to receive(:info_for_latest_step).
          and_return(step_info)
        expect(controller).to receive(:url_for).with(controller: '/idv/idv_step', action: :show).
          and_return('/verify')

        get :show
        expect(response.status).to eq 302
      end

      it 'does not redirect if the step is allowed' do
        expect(flow_policy).to receive(:controller_allowed?).
          with(controller: controller.class).and_return(true)

        get :show
        expect(response.body).to eq 'Hello'
        expect(response.status).to eq 200
      end
    end

    describe '#clear_future_steps! and #clear_future_steps_from!' do
      it 'calls undo_future_steps_from_controller!' do
        expect(flow_policy).to receive(:undo_future_steps_from_controller!).
          with(controller: controller.class)

        controller.send(:clear_future_steps!)
      end

      it 'sets latest_step_so_far' do
        idv_session.latest_step_so_far = nil
        stub_up_to(:phone, idv_session: idv_session)
        controller.send(:clear_future_steps_from!, controller: Idv::DocumentCaptureController)
        expect(idv_session.latest_step_so_far).to eq('otp_verification')
      end
    end
  end
end
