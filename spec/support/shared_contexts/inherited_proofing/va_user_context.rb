RSpec.shared_context 'va_user_context' do
  # As given to us from VA
  let(:user_attributes) do
    { first_name: 'Fakey',
      last_name: 'Fakerson',
      address: { street: '123 Fake St',
                 street2: 'Apt 235',
                 city: 'Faketown',
                 state: 'WA',
                 country: nil,
                 zip: '98037' },
      phone: '2063119187',
      birth_date: '2022-1-31',
      ssn: '123456789' }
  end
  # Encrypted with AppArtifacts.store.oidc_private_key for testing
  let(:encrypted_user_attributes) { File.read("#{__dir__}/encrypted_user_attributes.json") }
end
