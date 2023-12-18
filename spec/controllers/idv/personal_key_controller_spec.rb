require 'rails_helper'

RSpec.describe Idv::PersonalKeyController do
  include SamlAuthHelper
  include PersonalKeyValidator

  def assert_personal_key_generated_for_profiles(*profile_pii_pairs)
    expect(idv_session.personal_key).to be_present

    normalized_personal_key = normalize_personal_key(idv_session.personal_key)

    # These keys are present in our applicant fixture but
    # are not actually supported in Pii::Attributes
    keys_to_ignore = %i[
      state_id_expiration
      state_id_issued
      state_id_number
      state_id_type
    ]

    profile_pii_pairs.each do |profile, pii|
      expected = Pii::Attributes.new(pii.except(*keys_to_ignore))
      actual = profile.reload.recover_pii(normalized_personal_key)
      expect(actual).to eql(expected)
    end
  end

  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :fully_registered, password: password) }

  # Most (but not all) of these tests assume that a profile has been minted
  # from the data in idv_session. Set this to false to prevent this behavior
  # and test the other way.
  # (idv_session.profile will be nil if the user is coming back to complete
  # the IdV flow out-of-band, like with GPO.)
  let(:mint_profile_from_idv_session) { true }

  let(:address_verification_mechanism) { 'phone' }

  let(:in_person_enrollment) { nil }

  let(:idv_session) { subject.idv_session }

  let(:threatmetrix_review_status) { nil }

  before do
    stub_analytics
    stub_attempts_tracker
    stub_verify_steps_one_and_two(user, applicant: applicant)

    case address_verification_mechanism
    when 'phone'
      idv_session.address_verification_mechanism = 'phone'
      idv_session.user_phone_confirmation = true
      idv_session.vendor_phone_confirmation = true
      idv_session.gpo_code_verified = false
    when 'gpo'
      idv_session.address_verification_mechanism = 'gpo'
      idv_session.user_phone_confirmation = false
      idv_session.vendor_phone_confirmation = false
      idv_session.gpo_code_verified = true
    when nil
      idv_session.address_verification_mechanism = nil
      idv_session.user_phone_confirmation = nil
      idv_session.vendor_phone_confirmation = nil
    else
      raise 'invalid address_verification_mechanism'
    end

    idv_session.threatmetrix_review_status = threatmetrix_review_status

    if mint_profile_from_idv_session
      idv_session.create_profile_from_applicant_with_password(password)
    end
  end

  describe '#step_info' do
    let(:step_info) do
      controller.class.step_info
    end

    describe '#undo_step' do
      it 'clears personal_key_acknowledged' do
        idv_session.acknowledge_personal_key!
        step_info.undo_step.call(idv_session: idv_session, user: user)
        expect(idv_session.personal_key_acknowledged).to eql(nil)
      end
    end

    describe '#preconditions' do
      let(:preconditions) do
        step_info.preconditions.call(idv_session: idv_session, user: user)
      end

      context 'when all conditions met' do
        it 'returns a truthy result' do
          expect(preconditions).to be_truthy
        end
      end

      context 'when user does not have a pending or active profile' do
        before do
          user.active_profile.deactivate(:password_reset)
          expect(user.active_profile).to eql(nil)
          user.reload
        end

        it 'returns something falsey' do
          expect(preconditions).to be_falsey
        end
      end

      context 'when address confirmed via GPO' do
        let(:address_verification_mechanism) { 'gpo' }
        it 'returns a truthy result' do
          expect(preconditions).to be_truthy
        end
      end

      context 'when address confirmed via phone' do
        let(:address_verification_mechanism) { 'phone' }
        it 'returns a truthy result' do
          expect(preconditions).to be_truthy
        end
      end

      context 'when address unconfirmed' do
        let(:address_verification_mechanism) { nil }
        it 'returns a falsey result' do
          expect(preconditions).to be_falsey
        end
      end

      context 'when personal_key_acknowledged is false' do
        before do
          idv_session.personal_key_acknowledged = false
        end
        it 'returns a truthy result' do
          expect(preconditions).to be_truthy
        end
      end

      context 'when personal_key_acknowledged is true' do
        before do
          idv_session.personal_key_acknowledged = true
        end
        it 'returns a falsey result' do
          expect(preconditions).to be_falsey
        end
      end

      context 'when personal_key_acknowledged is nil' do
        before do
          idv_session.personal_key_acknowledged = nil
        end
        it 'returns a truthy result' do
          expect(preconditions).to be_truthy
        end
      end
    end
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_step_allowed,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(
        :before,
        :redirect_unless_sp_requested_verification,
      )
    end
  end

  describe '#show' do
    context 'profile has been created from idv_session' do
      it 'does not redirect' do
        get :show

        expect(response).to_not be_redirect
      end

      context 'profile is pending fraud review' do
        let(:threatmetrix_review_status) { 'reject' }
        it 'does not redirect' do
          get :show
          expect(response).to_not be_redirect
        end
      end
    end

    context 'profile has not been created from idv_session' do
      let(:mint_profile_from_idv_session) { false }

      it 'redirects to the account path' do
        get :show
        expect(response).to redirect_to idv_welcome_path
      end

      context 'but a profile is pending from a different session' do
        context 'due to fraud review' do
          let!(:pending_profile) { create(:profile, :fraud_review_pending, user: user) }

          it 'does not redirect' do
            get :show
            expect(response).not_to be_redirect
          end
        end

        context 'due to in person proofing' do
          let!(:pending_profile) { create(:profile, :in_person_verification_pending, user: user) }

          it 'does not redirect' do
            get :show
            expect(response).to_not be_redirect
          end
        end
      end
    end

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

      it 'redirects to letter enqueued url' do
        get :show

        expect(response).to redirect_to idv_letter_enqueued_url
      end
    end

    context 'no personal key generated yet' do
      before do
        idv_session.personal_key = nil
      end

      it 'generates a personal key that encrypts the idv_session profile data' do
        get :show
        assert_personal_key_generated_for_profiles([idv_session.profile, applicant])
      end

      context 'user has an existing profile in addition to the one attached to idv_session' do
        let(:existing_profile_pii) { idv_session.applicant.merge(first_name: 'Existing') }
        let!(:existing_profile) do
          create(
            :profile,
            :verify_by_mail_pending,
            user: user,
            pii: existing_profile_pii,
          )
        end

        before do
          Pii::Cacher.new(user, subject.user_session).save_decrypted_pii(
            existing_profile_pii,
            existing_profile.id,
          )
        end

        it 'generates a personal key that encrypts the idv_session and existing profile data' do
          expect(user.profiles).to include(existing_profile)
          expect(user.profiles).to include(idv_session.profile)
          get :show
          assert_personal_key_generated_for_profiles(
            [idv_session.profile, idv_session.applicant],
            [existing_profile, existing_profile_pii],
          )
        end
      end

      context 'no profile attached to idv_session' do
        let(:mint_profile_from_idv_session) { false }

        context 'user has a pending profile' do
          let!(:pending_profile_pii) { applicant.merge(first_name: 'Pending') }
          let!(:pending_profile) do
            create(
              :profile,
              :verify_by_mail_pending,
              user: user,
              pii: pending_profile_pii,
            )
          end

          before do
            Pii::Cacher.new(user, subject.user_session).save_decrypted_pii(
              pending_profile_pii,
              pending_profile.id,
            )
          end

          it 'generates a personal key that encrypts the pending profile data' do
            get :show
            assert_personal_key_generated_for_profiles([pending_profile, pending_profile_pii])
          end

          context 'and user has an active profile' do
            let(:active_profile_pii) { applicant.merge(first_name: 'Active') }
            let!(:active_profile) do
              create(
                :profile,
                :active,
                user: user,
                pii: active_profile_pii,
              )
            end

            before do
              Pii::Cacher.new(user, subject.user_session).save_decrypted_pii(
                active_profile_pii,
                active_profile.id,
              )
            end

            it 'generates a personal key that encrypts both profiles' do
              get :show
              assert_personal_key_generated_for_profiles(
                [active_profile, active_profile_pii],
                [pending_profile, pending_profile_pii],
              )
            end
          end
        end
      end
    end

    context 'personal key already acknowledged' do
      before do
        idv_session.acknowledge_personal_key!
      end
      it 'redirects away' do
        get :show
        expect(response).to be_redirect
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

      it 'redirects to correct url' do
        patch :update
        expect(response).to redirect_to idv_letter_enqueued_url
      end

      it 'does not log any events' do
        expect(@analytics).not_to have_logged_event
        patch :update
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
