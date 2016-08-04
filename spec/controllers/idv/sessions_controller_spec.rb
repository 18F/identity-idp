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
        post :create, user_attrs
        post :update, id: 1, ccn: '12341234'

        expect(flash).to be_empty
        expect(response).to redirect_to(idv_questions_path)
        expect(subject.user_session[:idv][:applicant]).to be_a Proofer::Applicant
      end

      it 'shows failure on intentionally bad values' do
        post :create, first_name: 'Bad', ssn: '6666'
        post :update, id: 1, ccn: '12341234'

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to eq t('idv.titles.fail')
      end

      it 'disallows duplicate SSN' do
        create(:profile, ssn: '1234')

        post :create, ssn: '1234'

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to include t('idv.errors.duplicate_ssn')
      end

      it 'checks for required fields' do
        partial_attrs = user_attrs.dup
        partial_attrs.delete :first_name

        post :create, partial_attrs

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to include "#{t('idv.form.first_name')} is required"
      end
    end

    context 'KBV off' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
      end

      it 'skips questions creation' do
        post :create, user_attrs
        post :update, id: 1, ccn: '12341234'

        expect(subject.user_session[:idv][:resolution].questions).to be_nil
      end

      it 'shows failure on intentionally bad values' do
        post :create, first_name: 'Bad', ssn: '6666'
        post :update, id: 1, ccn: '12341234'

        expect(response).to redirect_to(idv_sessions_path)
        expect(flash[:error]).to eq t('idv.titles.fail')
      end
    end
  end
end
