require 'rails_helper'

describe Idv::InPerson::VerifyInfoController do
  include IdvHelper

  let(:user) { build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end

    it 'confirms verify step not already complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_profile_not_already_confirmed,
      )
    end

    it 'renders 404 if feature flag not set' do
      allow(IdentityConfig.store).to receive(:doc_auth_in_person_verify_info_controller_enabled).
        and_return(false)

      get :show

      expect(response).to be_not_found
    end
  end
end