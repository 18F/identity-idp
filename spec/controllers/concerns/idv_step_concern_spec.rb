require 'rails_helper'

RSpec.describe 'IdvStepConcern' do
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

      it 'redirects to activated page' do
        get :show

        expect(response).to redirect_to idv_activated_url
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

  describe '#confirm_address_step_complete' do
    controller(idv_step_controller_class) do
      before_action :confirm_address_step_complete
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'anonymous#show'
      end
    end

    context 'the user has completed phone confirmation' do
      it 'does not redirect' do
        idv_session.vendor_phone_confirmation = true
        idv_session.user_phone_confirmation = true

        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end

    context 'the user has not confirmed their phone OTP' do
      it 'redirects to OTP confirmation' do
        idv_session.vendor_phone_confirmation = true
        idv_session.user_phone_confirmation = false

        get :show

        expect(response).to redirect_to(idv_otp_verification_url)
      end
    end

    context 'the user has not confirmed their phone with the vendor' do
      it 'redirects to phone confirmation' do
        idv_session.vendor_phone_confirmation = false
        idv_session.user_phone_confirmation = false

        get :show

        expect(response).to redirect_to(idv_otp_verification_url)
      end
    end

    context 'the user has selected GPO for address confirmation' do
      it 'does not redirect' do
        idv_session.address_verification_mechanism = 'gpo'

        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
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
end
