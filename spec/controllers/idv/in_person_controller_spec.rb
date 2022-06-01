require 'rails_helper'

describe Idv::InPersonController do
  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :fsm_initialize,
        :ensure_correct_step,
      )
    end
  end

  describe 'unauthenticated', :skip_sign_in do
    it 'redirects to the root url' do
      get :index

      expect(response).to redirect_to root_url
    end
  end

  describe '#index' do
    before do |example|
      stub_sign_in unless example.metadata[:skip_sign_in]
      stub_analytics
      allow(@analytics).to receive(:track_event)
      allow(Identity::Hostdata::EC2).to receive(:load).
          and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
    end

    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_in_person_step_url(step: :location)
    end
  end
end
