require 'rails_helper'

RSpec.describe EffectiveUser, type: :controller do
  controller ApplicationController do
    include EffectiveUser
  end

  let(:user) { create(:user) }

  describe '#effective_user' do
    subject { controller.effective_user }

    context 'logged out' do
      it 'returns nil' do
        expect(subject).to be_nil
      end

      context 'with valid doc capture session user id' do
        before do
          session[:doc_capture_user_id] = user.id
        end

        it 'returns session user id' do
          expect(subject).to eq user
        end
      end

      context 'with invalid doc capture session user id' do
        before do
          session[:doc_capture_user_id] = -1
        end

        it 'returns session user id' do
          expect(subject).to be_nil
        end

        it 'deletes the session key' do
          subject
          expect(session).not_to include(:doc_capture_user_id)
        end
      end
    end

    context 'non-existent user' do
      it 'returns session user id' do
        expect(subject).to be_nil
      end
    end

    context 'logged in' do
      before do
        stub_sign_in user
      end

      it 'returns session user id' do
        expect(subject).to eq user
      end

      context 'with valid doc capture session user id that is not the logged-in user' do
        let(:doc_capture_user) { create(:user) }

        before do
          session[:doc_capture_user_id] = doc_capture_user.id
        end

        it 'returns doc capture user id' do
          expect(subject).to eq(doc_capture_user)
        end
      end

      context 'with invalid doc capture session user id' do
        before do
          session[:doc_capture_user_id] = -1
        end

        it 'returns logged in user' do
          expect(subject).to eql(user)
        end

        it 'deletes the session key' do
          subject
          expect(session).not_to include(:doc_capture_user_id)
        end
      end
    end
  end
end
