require 'rails_helper'

RSpec.describe 'MfaSetupConcern' do
  controller ApplicationController do
    include MfaSetupConcern
  end

  describe '#show_skip_additional_mfa_link?' do
    let(:user) { create(:user, :fully_registered) }

    subject(:show_skip_additional_mfa_link?) { controller.show_skip_additional_mfa_link? }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    it 'returns true' do
      expect(show_skip_additional_mfa_link?).to eq(true)
    end

    context 'with only webauthn_platform registered' do
      let(:user) { create(:user, :with_webauthn_platform) }

      before do
        stub_sign_in(user)
      end

      it 'returns false' do
        expect(show_skip_additional_mfa_link?).to eq(false)
      end
    end
  end
end
