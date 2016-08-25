require 'rails_helper'

describe Idv::SessionsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666661234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  context 'user has created account' do
    before do
      sign_in(user)
    end

    context 'KBV on' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
      end

      it 'starts new proofing session' do
        get :index

        expect(response.status).to eq 200
        expect(response.body).to include t('idv.form.first_name')
      end

      it 'creates proofing applicant' do
        post :create, profile: user_attrs
        post :update_finance, ccn: '12341234'
        post :update_phone, phone: user.phone
        post :update_review

        expect(flash).to be_empty
        expect(response).to redirect_to(idv_questions_path)
        expect(subject.user_session[:idv][:applicant]).to be_a Proofer::Applicant
      end

      it 'shows failure on intentionally bad values' do
        post :create, profile: user_attrs.merge(first_name: 'Bad', ssn: '6666')
        post :update_finance, ccn: '12341234'
        post :update_phone, phone: user.phone
        post :update_review

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to eq t('idv.titles.fail')
      end

      it 'disallows duplicate SSN' do
        create(:profile, ssn: '1234')

        post :create, profile: user_attrs.merge(ssn: '1234')

        expect(response).to render_template(:index)
        expect(response.body).to match t('idv.errors.duplicate_ssn')
      end

      it 'checks for required fields' do
        partial_attrs = user_attrs.dup
        partial_attrs.delete :first_name

        post :create, profile: partial_attrs

        expect(response).to render_template(:index)
        expect(response.body).to match 'can&#39;t be blank'
      end
    end

    context 'KBV off' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
      end

      it 'skips questions creation' do
        post :create, profile: user_attrs
        post :update_finance, ccn: '12341234'
        post :update_phone, phone: user.phone
        post :update_review

        expect(subject.user_session[:idv][:resolution].questions).to be_nil
      end

      it 'shows failure on intentionally bad values' do
        post :create, profile: user_attrs.merge(first_name: 'Bad', ssn: '6666')
        post :update_finance, ccn: '12341234'
        post :update_phone, phone: user.phone
        post :update_review

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to eq t('idv.titles.fail')
      end
    end

    context 'multi-step forms' do
      it 'is re-entrant' do
        post :create, profile: user_attrs
        post :update_finance, ccn: '12341234'

        expect(subject.user_session[:idv][:params]['ccn']).to eq '12341234'

        post :update_finance, ccn: '55556666'

        expect(subject.user_session[:idv][:params]['ccn']).to eq '55556666'
      end

      it 'requires confirmation for new phone' do
        post :create, profile: user_attrs
        post :update_finance, ccn: '12341234'
        post :update_phone, phone: '1233334444'
        post :update_review

        expect(response).to redirect_to(idv_phone_confirmation_send_path)
      end
    end
  end
end
