require 'rails_helper'

RSpec.describe AccountRecoverySuspendable do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :replacement_mfa_pending, user: user) }

  %i[phone_configuration auth_app_configuration webauthn_configuration
     piv_cac_configuration backup_code_configuration].each do |factory|
    it "excludes a suspended #{factory} from authentication without deleting it" do
      configuration = create(factory, user: user, account_recovery_request_id: recovery_request.id)

      expect(configuration).not_to be_mfa_enabled
      expect(configuration.selection_presenters).to be_empty
      expect(configuration.class.available_for_authentication).not_to include(configuration)
      expect(configuration.class.exists?(configuration.id)).to eq(true)
    end
  end
end
