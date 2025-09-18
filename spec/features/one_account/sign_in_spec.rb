require 'rails_helper'

RSpec.feature 'One Account Sign In' do
  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include OidcAuthHelper
  include SpAuthHelper
  include IdvHelper
  include DocAuthHelper
  include AbTestsHelper

  let(:user) { create(:user, :fully_registered, :proofed_with_selfie) }
  let(:service_provider) { create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:server') }
  let(:pii_attrs) do
    {
      first_name: 'John',
      last_name: 'Doe',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      address1: '123 Main St',
      city: 'Anytown',
      state: 'NY',
      zipcode: '12345'
    }
  end

  context 'with One Account Enabled for SP' do
    let(:user) { create(:user, :proofed_with_selfie) }
    scenario 'with User with profile' do
      visit_idp_from_ial2_oidc_sp(facial_match_required: true)
    end
  end

  context 'with One account disabled for SP' do

  end
end
