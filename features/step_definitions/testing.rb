# frozen_string_literal: true

require_relative '../../lib/saml_idp_constants'

Given('A user is logged in') do
  @user = FactoryBot.create(
    :user, :fully_registered, with: { phone: '+1 202-555-1212' },
                              password: 'Val!d Pass w0rd'
  )
  @service_provider = FactoryBot.create(:service_provider, :active, :in_person_proofing_enabled)

  visit_idp_from_sp_with_ial2(:oidc, **{ client_id: @service_provider.issuer })
  sign_in_via_branded_page(@user)
end

When('I run cucumber') do
end

Then('This should pass') do
  expect(true).to be(false)
end
