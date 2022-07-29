RSpec.shared_context 'inherited_proofing' do
  let(:auth_code) {}
  let(:private_key) { private_key_from_store_or(file_name: 'va_ip.key') }
  let(:payload) { { inherited_proofing_auth: auth_code, exp: 1.day.from_now.to_i } }
  let(:jwt_token) { JWT.encode(payload, private_key, 'RS256') }
  let(:request_uri) {
    "#{InheritedProofing::Va::Service::BASE_URI}/inherited_proofing/user_attributes"
  }
  let(:request_headers) { { Authorization: "Bearer #{jwt_token}" } }
  let(:user_attributes) {
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
  }
  let(:encrypted_user_attributes) {
    '{"data":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkExMjhHQ00ifQ.aE7sR9_LEg3fJsM6OGZovCn1HgNnmOb5j5oY_'\
    'KCW5Ps1nBtUKIstX5R6jUzoDz9S33SFJOz0co4Ni5P-n5Nz3poy4euG1VkfvBU5tgeOESQlRZAa1MaHltQ5cvCwzhgzxV'\
    'WF3UhasPwNXTSzDKRyBsFjlpGz2cFtjAQmn_5KN55KveQRHrd8CLWwnyLuUr-OIRV33xsmBFFmKwLz2_pJ0I2qVRiBBfY'\
    'BJAj8POMvHcb8jcTj3hVPmuSykY1MxficNldhpTycmrbAKS8bmH0GQPW9keeya7_Bbd68W7CaKTdxqLEYq6bnq2ZEr2m2'\
    'nnNX4sBY_RH01P-pRceIYlP0Ow.ROTfFXEdsyEZ6fkN.ECi341meAV5kjhmp_OZqbskPM140QUAaqKaOUZS7ClV6NZ9BQ'\
    '9ekukJOKtmyGICudZ6VJrv1WMy2IftSOjwTkjWXxxtBPxvoGqqeDuToennRmVC130ivPH-voAT3NwlwMRqyGuZZmegNo9'\
    'e4bIjUTnAoz3sglAxtB1YMLSaxD70hzPA9vNMVDu09K_zha9AwMm5VFf4tg-R7SJ_2wYkiMIe38dofCwtZ89WFkdJz2SL'\
    'p8FSUWRjOwtonxIrp2xHPqFB0yBzAN6ZjxbzwR0ax9W666hb6SiG1ByAh14jCmOM.CI4-YIi-7PDbvXGfsUF4kQ"}'
  }
end
