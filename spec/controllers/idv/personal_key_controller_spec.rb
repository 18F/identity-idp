require 'rails_helper'

RSpec.describe Idv::PersonalKeyController do
  include SamlAuthHelper
  include PersonalKeyValidator

  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :fully_registered, password: password) }

  # Most (but not all) of these tests assume that a profile has been minted
  # from the data in idv_session. Set this to false to prevent this behavior
  # and test the other way.
  let(:mint_profile_from_idv_session) { true }

  let(:address_verification_mechanism) { 'phone' }

  let(:in_person_enrollment) { nil }

  let(:idv_session) { subject.idv_session }

  before do
    stub_analytics
    stub_attempts_tracker
    stub_verify_steps_one_and_two(user, applicant: applicant)

    case address_verification_mechanism
    when 'phone'
      idv_session.address_verification_mechanism = 'phone'
      idv_session.user_phone_confirmation = true
      idv_session.vendor_phone_confirmation = true
    when 'gpo'
      idv_session.address_verification_mechanism = 'gpo'
      idv_session.user_phone_confirmation = false
      idv_session.vendor_phone_confirmation = false
    else
      raise 'invalid address_verification_mechanism'
    end

    if mint_profile_from_idv_session
      idv_session.create_profile_from_applicant_with_password(password)
    end
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_phone_or_address_confirmed,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end

    describe '#confirm_profile_has_been_created' do
      controller do
        before_action :confirm_profile_has_been_created

        def index
          render plain: 'Hello'
        end
      end

      context 'profile has been created' do
        it 'does not redirect' do
          get :index

          expect(response).to_not be_redirect
        end
      end

      context 'profile has not been created from idv_session' do
        let(:mint_profile_from_idv_session) { false }

        it 'redirects to the account path' do
          get :index
          expect(response).to redirect_to account_path
        end

        context 'profile is pending from a different session' do
          context 'profile is pending due to fraud review' do
            let!(:pending_profile) { create(:profile, :fraud_review_pending, user: user) }

            it 'does not redirect' do
              get :index
              expect(response).to_not be_redirect
            end
          end

          context 'profile is pending due to in person proofing' do
            let!(:pending_profile) { create(:profile, :in_person_verification_pending, user: user) }

            it 'does not redirect' do
              get :index
              expect(response).to_not be_redirect
            end
          end
        end
      end
    end
  end

  describe '#show' do
    it 'sets code instance variable' do
      code = idv_session.personal_key
      expect(code).to be_present

      get :show

      expect(assigns(:code)).to eq(code)
    end

    it 'shows the same personal key when page is refreshed' do
      code = idv_session.personal_key
      expect(code).to be_present

      get :show
      get :show

      expect(assigns(:code)).to eq(code)
    end

    it 'can decrypt the profile with the code' do
      get :show

      code = assigns(:code)

      expect(PersonalKeyGenerator.new(user).verify(code)).to eq true
      expect(idv_session.profile.recover_pii(normalize_personal_key(code))).to eq(
        Pii::Attributes.new_from_hash(applicant),
      )
    end

    it 'logs when user generates personal key' do
      expect(@irs_attempts_api_tracker).to receive(:idv_personal_key_generated)
      get :show
    end

    context 'user selected gpo verification' do
      let(:address_verification_mechanism) { 'gpo' }

      it 'redirects to enter password url' do
        get :show

        expect(response).to redirect_to idv_enter_password_url
      end
    end
  end

  describe '#update' do
    context 'user selected phone verification' do
      it 'redirects to sign up completed for an sp' do
        subject.session[:sp] = { ial2: true }
        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end

      it 'redirects to the account path when no sp present' do
        patch :update

        expect(response).to redirect_to account_path
      end

      it 'clears need_personal_key_confirmation session state' do
        subject.user_session[:need_personal_key_confirmation] = true
        patch :update

        expect(subject.user_session[:need_personal_key_confirmation]).to eq(false)
      end

      it 'sets idv_session.personal_key_acknowledged' do
        expect { patch :update }.to change {
                                      idv_session.personal_key_acknowledged
                                    }.from(nil).to eql(true)
      end

      it 'logs key submitted event' do
        patch :update

        expect(@analytics).to have_logged_event(
          'IdV: personal key submitted',
          address_verification_method: 'phone',
          fraud_review_pending: false,
          fraud_rejection: false,
          in_person_verification_pending: false,
          deactivation_reason: nil,
          proofing_components: nil,
        )
      end
    end

    context 'user selected gpo verification' do
      let(:address_verification_mechanism) { 'gpo' }

      it 'redirects to review url' do
        patch :update

        expect(response).to redirect_to idv_enter_password_url
      end
    end

    context 'with in person profile' do
      let!(:in_person_enrollment) do
        create(:in_person_enrollment, :pending, user: user).tap do
          user.reload_pending_in_person_enrollment
        end
      end

      before do
        ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'creates a profile and returns completion url' do
        patch :update

        expect(response).to redirect_to idv_in_person_ready_to_verify_url
      end

      it 'logs key submitted event' do
        patch :update

        expect(@analytics).to have_logged_event(
          'IdV: personal key submitted',
          address_verification_method: 'phone',
          fraud_review_pending: false,
          fraud_rejection: false,
          deactivation_reason: nil,
          in_person_verification_pending: false,
          proofing_components: nil,
        )
      end
    end

    context 'with device profiling decisioning enabled' do
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      end

      context 'fraud_review_pending_at is nil' do
        it 'redirects to account path' do
          patch :update

          expect(idv_session.profile.fraud_review_pending_at).to eq nil
          expect(response).to redirect_to account_path
        end

        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            address_verification_method: 'phone',
            fraud_review_pending: false,
            fraud_rejection: false,
            in_person_verification_pending: false,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end

      context 'profile is in fraud_review' do
        before do
          idv_session.profile.fraud_pending_reason = 'threatmetrix_review'
          idv_session.profile.deactivate_for_fraud_review
        end

        it 'redirects to idv please call path' do
          patch :update
          expect(idv_session.profile.fraud_review_pending_at).to_not eq nil
          expect(response).to redirect_to idv_please_call_path
        end

        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            fraud_review_pending: true,
            fraud_rejection: false,
            address_verification_method: 'phone',
            in_person_verification_pending: false,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end
    end
  end
end
