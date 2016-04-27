require 'rails_helper'

describe Devise::SecurityQuestionsController, devise: true do
  describe 'POST :check' do
    it 'checks their answers' do
      user = create(:user, :signed_up)
      token = user.send(:set_reset_password_token)

      answer = {
        'id' => '1',
        'answer' => 'foo'
      }
      expect_any_instance_of(User).to receive(:check_security_question_answers).with([answer])

      post :check, reset_password_token: token, user: {
        security_answers_attributes: {
          '0' => answer
        }
      }
    end

    context 'exceeded attempts' do
      let!(:user) do
        create(
          :user,
          :signed_up,
          security_question_attempts_count: Devise.max_security_questions_attempts
        )
      end

      let!(:token) { user.send(:set_reset_password_token) }

      it "doesn't check the answers" do
        expect_any_instance_of(User).to_not receive(:check_security_question_answers)
        post :check, reset_password_token: token
      end

      it 'takes them to the homepage' do
        post :check, reset_password_token: token

        expect(response).to redirect_to('/')
        expect(flash[:error]).to eq(t('errors.messages.max_security_questions_attempts'))
      end
    end
  end

  describe 'GET :confirm' do
    let!(:user) { create(:user, :signed_up) }
    let!(:token) { user.send(:set_reset_password_token) }

    let!(:user_with_inactive_question) { create(:user, :tfa_confirmed, :with_inactive_security_question) }
    let!(:inactive_question_token) { user_with_inactive_question.send(:set_reset_password_token) }

    context 'invalid token' do
      it 'redirects to forgot password? page' do
        get :confirm, reset_password_token: '12345678'

        expect(response).to redirect_to('/users/password/new')
        expect(flash[:error]).to eq(t('devise.passwords.invalid_token'))
      end
    end

    context 'valid token' do
      it 'returns a 200 status code' do
        get :confirm, reset_password_token: token

        expect(response.status).to eq 200
      end
    end

    context 'user with inactive question' do
      it 'includes inactive questions in the sample' do
        expect_any_instance_of(User).to receive_message_chain(:security_answers, :sample)

        get :confirm, reset_password_token: inactive_question_token
      end
    end
  end

  describe 'update' do
    context 'using POST' do
      it 'responds to POST request' do
        sign_in_as_user

        post :update, user: { security_answers_attributes: { '0' => {} } }

        expect(flash[:error]).to eq t('upaya.errors.duplicate_questions')
      end
    end

    context 'using PATCH' do
      it 'responds to PATCH request' do
        sign_in_as_user

        patch :update, user: { security_answers_attributes: { '0' => {} } }

        expect(flash[:error]).to eq t('upaya.errors.duplicate_questions')
      end
    end
  end
end
