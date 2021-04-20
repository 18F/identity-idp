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
    end

    context 'non-existent user' do
      before do
        session[:ial2_recovery_user_id] = -1
      end

      it 'returns session user id' do
        expect(subject).to be_nil
      end
    end

    context 'logged out with ial2 recovery session user id' do
      before do
        session[:ial2_recovery_user_id] = user.id
      end

      it 'returns session user id' do
        expect(subject).to eq user
      end
    end

    context 'logged out with doc capture session user id' do
      before do
        session[:doc_capture_user_id] = user.id
      end

      it 'returns session user id' do
        expect(subject).to eq user
      end
    end

    context 'logged in' do
      before do
        stub_sign_in user
      end

      it 'returns session user id' do
        expect(subject).to eq user
      end
    end
  end
end
