require 'rails_helper'

describe 'Strict IAL2 feature flag' do
  include IdvHelper
  include OidcAuthHelper

  scenario 'returns an error if liveness checking is disabled' do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(false)

    visit_idp_from_oidc_sp_with_ial2_strict

    expect(current_url).to start_with(
      'http://localhost:7654/auth/result?error=invalid_request'\
      '&error_description=Acr+values+Liveness+checking+is+disabled',
    )
  end
end
