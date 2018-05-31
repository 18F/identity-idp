class AddressMock < Proofer::Base
  attributes :phone

  stage :address

  proof do |applicant, result|
    plain_phone = applicant[:phone].gsub(/\D/, '').gsub(/\A1/, '')
    if plain_phone == '5555555555'
      result.add_error(:phone, 'The phone number could not be verified.')
    end
    result.context[:message] = 'some context for the mock address proofer'
  end
end
