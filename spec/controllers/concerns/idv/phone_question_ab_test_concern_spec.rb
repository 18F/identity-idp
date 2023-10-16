require 'rails_helper'

RSpec.describe Idv::PhoneQuestionAbTestConcern do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  controller(ApplicationController) do
    include Idv::PhoneQuestionAbTestConcern

    before_action :maybe_redirect_for_phone_question_ab_test

    def index
      render plain: 'Hello'
    end
  end

  describe '#phone_question_ab_test_bucket' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(AbTests::IDV_PHONE_QUESTION).to receive(:bucket) do |discriminator|
        case discriminator
        when user.uuid
          :show_phone_question
        else :bypass_phone_question
        end
      end
    end

    it 'returns the bucket based on user id' do
      expect(controller.phone_question_ab_test_bucket).to eq(:show_phone_question)
    end

    context 'with a different user' do
      before do
        user2 = create(:user, :fully_registered, email: 'new_email@example.com')
        allow(controller).to receive(:current_user).and_return(user2)
      end
      it 'returns the bucket based on user id' do
        expect(controller.phone_question_ab_test_bucket).to eq(:bypass_phone_question)
      end
    end
  end

  describe '#phone_question_user' do
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
        expect(controller.phone_question_user).to eq(document_capture_user)
      end
    end

    context 'when falling back to current_user' do
      it 'falls back to current_user when document_capture_user undefined' do
        expect(controller.phone_question_user).to eq(current_user)
      end
    end
  end

  context '#maybe_redirect_for_phone_question_ab_test' do
    before do
      sign_in(user)
    end

    context 'A/B test specifies phone question page' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:show_phone_question)
      end

      it 'redirects to idv_phone_question_url' do
        get :index

        expect(response).to redirect_to(idv_phone_question_url)
      end

      context 'referred from phone question page' do
        let(:referer) { idv_phone_question_url }
        before do
          request.env['HTTP_REFERER'] = referer
        end
        it 'does not redirect users away from hybrid handoff page' do
          get :index

          expect(response.body).to eq('Hello')
          expect(response.status).to eq(200)
        end
      end
    end

    context 'A/B test specifies bypassing phone question page' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:bypass_phone_question)
      end

      it 'does not redirect users away from hybrid handoff page' do
        get :index

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end

    context 'A/B test specifies some other value' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:something_else)
      end

      it 'does not redirect users away from hybrid handoff page' do
        get :index

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end
  end
end
