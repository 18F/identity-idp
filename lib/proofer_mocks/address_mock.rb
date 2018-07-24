class AddressMock < Proofer::Base
  required_attributes :phone

  stage :address

  proof do |applicant, result|
    plain_phone = applicant[:phone].gsub(/\D/, '').gsub(/\A1/, '')
    if plain_phone == '7035555555'
      result.add_error(:phone, 'The phone number could not be verified.')
    end
    result.context[:message] = 'some context for the mock address proofer'
  end
end
