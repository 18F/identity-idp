require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end
  end

  describe '#update' do
    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end
  end
end
