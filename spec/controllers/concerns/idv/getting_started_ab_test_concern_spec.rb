require 'rails_helper'

RSpec.describe Idv::GettingStartedAbTestConcern do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  controller(ApplicationController) do
    include Idv::GettingStartedAbTestConcern

    before_action :maybe_redirect_for_getting_started_ab_test

    def index
      render plain: 'Hello'
    end
  end

  describe '#getting_started_ab_test_bucket' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(AbTests::IDV_GETTING_STARTED).to receive(:bucket) do |discriminator|
        case discriminator
        when user.uuid
          :getting_started
        else :welcome
        end
      end
    end

    it 'returns the bucket based on user id' do
      expect(controller.getting_started_ab_test_bucket).to eq(:getting_started)
    end

    context 'with a different user' do
      before do
        user2 = create(:user, :fully_registered, email: 'new_email@example.com')
        allow(controller).to receive(:current_user).and_return(user2)
      end
      it 'returns the bucket based on user id' do
        expect(controller.getting_started_ab_test_bucket).to eq(:welcome)
      end
    end
  end

  describe '#getting_started_user' do
    let(:document_capture_user) { create(:user) }
    let(:current_user) { create(:user) }
    before do
      allow(controller).to receive(:current_user).and_return(current_user)
    end

    context 'when document_capture_user is defined (hybrid flow)' do
      before do
        allow(controller).to receive(:document_capture_user).and_return(document_capture_user)
      end

      it 'uses the document_capture_user to choose a bucket' do
        expect(controller.getting_started_user).to eq(document_capture_user)
      end
    end

    context 'when falling back to current_user' do
      it 'falls back to current_user when document_capture_user undefined' do
        expect(controller.getting_started_user).to eq(current_user)
      end
    end
  end

  context '#maybe_redirect_for_getting_started_ab_test' do
    before do
      sign_in(user)
    end

    context 'A/B test specifies getting started page' do
      before do
        allow(controller).to receive(:getting_started_ab_test_bucket).
          and_return(:getting_started)
      end

      it 'redirects to idv_getting_started_url' do
        get :index

        expect(response).to redirect_to(idv_getting_started_url)
      end
    end

    context 'A/B test specifies welcome page' do
      before do
        allow(controller).to receive(:getting_started_ab_test_bucket).
          and_return(:welcome)
      end

      it 'does not redirect users away from welcome page' do
        get :index

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end

    context 'A/B test specifies some other value' do
      before do
        allow(controller).to receive(:getting_started_ab_test_bucket).
          and_return(:something_else)
      end

      it 'does not redirect users away from welcome page' do
        get :index

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end
  end
end
