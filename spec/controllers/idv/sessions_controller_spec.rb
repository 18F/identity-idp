require 'rails_helper'

RSpec.describe Idv::SessionsController do
  let(:user) { build(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#destroy' do
    before do
      allow(idv_session).to receive(:clear)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      controller.user_session['idv/in_person'] = flow_session
      Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
        pii,
        '123',
      )
    end

    let(:idv_session) { double }
    let(:flow_session) { { x: {} } }

    let(:pii) { { first_name: 'Jane' } }

    context 'when destroying the session' do
      before do
        expect(idv_session).to receive(:clear)
        delete :destroy
      end

      it 'clears the idv/in_person session' do
        expect(controller.user_session['idv/in_person']).to be_blank
      end

      it 'clears the encrypted_profiles session' do
        expect(controller.user_session[:encrypted_profiles]).to be_blank
      end
    end

    it 'tracks the idv_start_over event in analytics' do
      delete :destroy, params: { step: 'first', location: 'get_help' }

      expect(@analytics).to have_logged_event(
        'IdV: start over',
        hash_including(
          location: 'get_help',
          step: 'first',
        ),
      )
    end

    context 'with in person enrollment' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      it 'logs idv_start_over event with extra analytics attributes for barcode step' do
        delete :destroy, params: { step: 'barcode', location: '' }
        expect(@analytics).to have_logged_event(
          'IdV: start over',
          hash_including(
            location: '',
            step: 'barcode',
            cancelled_enrollment: true,
            enrollment_code: user.pending_in_person_enrollment.enrollment_code,
            enrollment_id: user.pending_in_person_enrollment.id,
          ),
        )
      end
    end

    it 'redirect occurs to the start of identity verification' do
      delete :destroy

      expect(response).to redirect_to(idv_url)
    end

    context 'pending profile' do
      let(:user) do
        create(
          :user,
          profiles: [create(:profile, gpo_verification_pending_at: 1.day.ago)],
        )
      end

      it 'cancels verification attempt' do
        cancel = double
        expect(Idv::CancelVerificationAttempt).to receive(:new).and_return(cancel)
        expect(cancel).to receive(:call)

        delete :destroy, params: { step: 'gpo_verify', location: 'clear_and_start_over' }

        expect(@analytics).to have_logged_event(
          'IdV: start over',
          hash_including(
            location: 'clear_and_start_over',
            step: 'gpo_verify',
          ),
        )
      end
    end

    context 'with in person enrollment' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'cancels pending in person enrollment' do
        pending_enrollment = user.pending_in_person_enrollment
        expect(user.reload.pending_in_person_enrollment).to_not be_blank
        delete :destroy

        pending_enrollment.reload
        expect(pending_enrollment.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(user.reload.pending_in_person_enrollment).to be_blank
      end

      it 'cancels establishing in person enrollment' do
        establishing_enrollment = create(:in_person_enrollment, :establishing, user: user)
        expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(1)
        delete :destroy

        establishing_enrollment.reload
        expect(establishing_enrollment.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(0)
      end
    end
  end
end
