require 'rails_helper'

describe Idv::SsnController do
  include IdvHelper

  describe 'before_actions' do
    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :render_404_if_ssn_controller_disabled,
      )
    end

    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    context 'when doc_auth_ssn_controller_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
          and_return(false)
      end

      it 'returns 404' do
        get :show

        expect(response.status).to eq(404)
      end
    end
  end
end