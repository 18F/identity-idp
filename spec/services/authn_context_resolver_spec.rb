require 'rails_helper'

RSpec.describe AuthnContextResolver do
  it 'works for ACR values' do
    acr_values = [
      'http://idmanagement.gov/ns/assurance/aal/2?phishing_resistant=true',
      'http://idmanagement.gov/ns/assurance/ial/2',
    ].join(' ')

    result = AuthnContextResolver.new(
      service_provider: nil,
      vtr: nil,
      acr_values: acr_values,
    ).resolve

    # binding.pry
  end
end
