require 'rails_helper'

RSpec.describe NDS::OptOutController do
  describe '#create' do
    let(:experiment) { AbTests::NDS_LOOK_AND_FEEL.experiment }
    let(:discriminator) { controller.send(:nds_experiment_uuid) }

    it 'persists the opt_out assignment, updates the session, and redirects back' do
      create(:ab_test_assignment, experiment:, discriminator:, bucket: 'nds')
      referer = 'http://www.example.com/sign_up?source=agency'
      request.env['HTTP_REFERER'] = referer

      post :create

      expect(
        AbTestAssignment.bucket(
          experiment:,
          discriminator:,
        ),
      ).to eq(:opt_out)
      expect(session[:nds_ab_test_bucket]).to eq('opt_out')
      expect(response).to redirect_to(referer)
    end

    it 'logs the opt-out event' do
      create(:ab_test_assignment, experiment:, discriminator:, bucket: 'nds')
      stub_analytics

      post :create
      expect(@analytics).to have_logged_event(:nds_look_and_feel_opted_out)
    end

    it 'returns early when no assignment exists' do
      referer = 'http://www.example.com/sign_up?source=agency'
      request.env['HTTP_REFERER'] = referer

      post :create

      expect(session[:nds_ab_test_bucket]).to be_nil
      expect(response).to redirect_to(referer)
    end

    it 'redirects to the root path when there is no referer' do
      create(:ab_test_assignment, experiment:, discriminator:, bucket: 'nds')

      post :create

      expect(response).to redirect_to(root_path)
    end
  end
end
