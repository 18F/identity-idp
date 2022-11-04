require 'rails_helper'

shared_examples 'the idv/doc_auth session is cleared' do
  it 'clears the session' do
    expect(controller.user_session['idv/doc_auth']).to be_blank
  end
end

shared_examples 'the idv/in_person session is cleared' do
  it 'clears the session' do
    expect(controller.user_session['idv/in_person']).to be_blank
  end
end

shared_examples 'the idv/inherited_proofing session is cleared' do
  it 'clears the session' do
    expect(controller.user_session['idv/inherited_proofing']).to be_blank
  end
end

shared_examples 'the decrypted_pii session is cleared' do
  it 'clears the session' do
    expect(controller.user_session[:decrypted_pii]).to be_blank
  end
end

shared_examples 'a redirect occurs to the start of identity verification' do
  it 'redirects' do
    delete :destroy

    expect(response).to redirect_to(idv_url)
  end
end

shared_examples 'logs IDV start over analytics with step and location params' do
  it 'logs the analytics' do
    delete :destroy, params: { step: 'first', location: 'get_help' }

    expect(@analytics).to have_logged_event(
      'IdV: start over',
      step: 'first',
      location: 'get_help',
    )
  end
end

describe Idv::SessionsController do
  let(:user) { build(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#destroy' do
    before do
      allow(idv_session).to receive(:clear)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      controller.user_session['idv/doc_auth'] = { idv_doc_auth_session: true }
      controller.user_session['idv/in_person'] = { idv_in_person_session: true }
      controller.user_session['idv/inherited_proofing'] = { idv_idv_inherited_proofing_session: true }
      controller.user_session[:decrypted_pii] = pii
    end

    let(:idv_session) { double }
    let(:flow_session) { {} }
    let(:pii) { { first_name: 'Jane' } }

    context 'when destroying the session' do
      before do
        expect(idv_session).to receive(:clear)
        delete :destroy
      end

      it_behaves_like 'the idv/doc_auth session is cleared'
      it_behaves_like 'the idv/in_person session is cleared'
      it_behaves_like 'the idv/inherited_proofing session is cleared'
      it_behaves_like 'the decrypted_pii session is cleared'
    end

    it_behaves_like 'logs IDV start over analytics with step and location params'
    it_behaves_like 'a redirect occurs to the start of identity verification'

    context 'pending profile' do
      let(:user) do
        create(
          :user,
          profiles: [create(:profile, deactivation_reason: :gpo_verification_pending)],
        )
      end

      it 'cancels verification attempt' do
        cancel = double
        expect(Idv::CancelVerificationAttempt).to receive(:new).and_return(cancel)
        expect(cancel).to receive(:call)

        delete :destroy, params: { step: 'gpo_verify', location: 'clear_and_start_over' }
        expect(@analytics).to have_logged_event(
          'IdV: start over',
          step: 'gpo_verify',
          location: 'clear_and_start_over',
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
        expect(pending_enrollment.status).to eq('cancelled')
        expect(user.reload.pending_in_person_enrollment).to be_blank
      end

      it 'cancels establishing in person enrollment' do
        establishing_enrollment = create(:in_person_enrollment, :establishing, user: user)
        expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(1)
        delete :destroy

        establishing_enrollment.reload
        expect(establishing_enrollment.status).to eq('cancelled')
        expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(0)
      end
    end
  end
end
