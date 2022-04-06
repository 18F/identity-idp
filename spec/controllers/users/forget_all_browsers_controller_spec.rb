require 'rails_helper'

RSpec.describe Users::ForgetAllBrowsersController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  let(:original_device_revoked_at) { 30.days.from_now }

  let(:user) do
    create(:user, remember_device_revoked_at: original_device_revoked_at)
  end

  before do
    stub_sign_in(user)
  end

  describe '#show' do
    subject { get :show }

    it 'renders' do
      subject
      expect(response).to render_template(:show)
    end

    it 'logs an analytics event for visiting' do
      stub_analytics
      expect(@analytics).to receive(:track_event).with('Forget All Browsers Visited')

      subject
    end

    it 'does not change remember_device_revoked_at' do
      expect { subject }.to_not(change { user.remember_device_revoked_at.to_i })
    end
  end

  describe '#destroy' do
    subject { delete :destroy }

    it 'updates the remember_device_revoked_at attribute for the user' do
      now = Time.zone.now

      expect do
        freeze_time do
          travel_to(now)
          subject
        end
      end.to change { user.remember_device_revoked_at.to_i }.
        from(original_device_revoked_at.to_i).
        to(now.to_i)
    end

    it 'logs an analytics event for forgetting' do
      stub_analytics
      expect(@analytics).to receive(:track_event).with('Forget All Browsers Submitted')

      subject
    end

    it 'redirects to the account page' do
      subject

      expect(response).to redirect_to account_path
    end
  end
end
