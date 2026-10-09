require 'rails_helper'

RSpec.describe NDS::OptOutController do
  describe '#create' do
    let(:experiment) { AbTests::NDS_LOOK_AND_FEEL.experiment }
    let(:discriminator) { controller.send(:nds_experiment_uuid) }
    let(:referer) { 'http://www.example.com/sign_up?source=agency' }

    before { request.env['HTTP_REFERER'] = referer }

    it 'persists the opt_out assignment, updates the session, and redirects back' do
      create(:ab_test_assignment, experiment:, discriminator:, bucket: 'nds')

      post :create

      expect(AbTestAssignment.bucket(experiment:, discriminator:)).to eq(:opt_out)
      expect(session[:nds_ab_test_bucket]).to eq('opt_out')
      expect(response).to redirect_to(referer)
    end

    it 'logs the opt-out event with the previous bucket' do
      session[:nds_ab_test_bucket] = 'nds'
      stub_analytics

      post :create

      expect(@analytics).to have_logged_event(
        :nds_look_and_feel_opted_out,
        previous_bucket: 'nds',
      )
    end

    it 'creates the opt_out assignment when none exists' do
      post :create

      expect(AbTestAssignment.bucket(experiment:, discriminator:)).to eq(:opt_out)
      expect(session[:nds_ab_test_bucket]).to eq('opt_out')
      expect(response).to redirect_to(referer)
    end

    it 'clears the ui_test_bucket override cookie' do
      cookies[:ui_test_bucket] = 'nds'

      post :create

      expect(response.cookies).to include('ui_test_bucket' => nil)
    end

    it 'redirects to the root path when there is no referer' do
      request.env.delete('HTTP_REFERER')

      post :create

      expect(response).to redirect_to(root_path)
    end
  end
end
