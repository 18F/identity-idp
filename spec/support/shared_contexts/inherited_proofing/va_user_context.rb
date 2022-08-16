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

  let(:valid_user) do
    { uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      phone: '5551231234', }
  end
end
