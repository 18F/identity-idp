require 'rails_helper'

RSpec.describe SmsPreview::DailyVoiceLimitReachedController do
  describe '#show' do
    it 'shows the page' do
      get :show

      expect(response).to render_template :show
    end
  end
end
