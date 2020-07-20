require 'rails_helper'

RSpec.describe SecurityEventsController do
  include Rails.application.routes.url_helpers

  let(:identity) { build(:identity) }
  let(:user) { create(:user, identities: [ identity ]) }

<<-EOS
   POST /Events  HTTP/1.1

   Host: notify.examplerp.com
   Accept: application/json
   Authorization: Bearer h480djs93hd8
   Content-Type: application/secevent+jwt
   eyJhbGciOiJub25lIn0
   .
   eyJwdWJsaXNoZXJVcmkiOiJodHRwczovL3NjaW0uZXhhbXBsZS5jb20iLCJmZWV
   kVXJpcyI6WyJodHRwczovL2podWIuZXhhbXBsZS5jb20vRmVlZHMvOThkNTI0Nj
   FmYTViYmM4Nzk1OTNiNzc1NCIsImh0dHBzOi8vamh1Yi5leGFtcGxlLmNvbS9GZ
   WVkcy81ZDc2MDQ1MTZiMWQwODY0MWQ3Njc2ZWU3Il0sInJlc291cmNlVXJpcyI6
   WyJodHRwczovL3NjaW0uZXhhbXBsZS5jb20vVXNlcnMvNDRmNjE0MmRmOTZiZDZ
   hYjYxZTc1MjFkOSJdLCJldmVudFR5cGVzIjpbIkNSRUFURSJdLCJhdHRyaWJ1dG
   VzIjpbImlkIiwibmFtZSIsInVzZXJOYW1lIiwicGFzc3dvcmQiLCJlbWFpbHMiX
   SwidmFsdWVzIjp7ImVtYWlscyI6W3sidHlwZSI6IndvcmsiLCJ2YWx1ZSI6Impk
   b2VAZXhhbXBsZS5jb20ifV0sInBhc3N3b3JkIjoibm90NHUybm8iLCJ1c2VyTmF
   tZSI6Impkb2UiLCJpZCI6IjQ0ZjYxNDJkZjk2YmQ2YWI2MWU3NTIxZDkiLCJuYW
   1lIjp7ImdpdmVuTmFtZSI6IkpvaG4iLCJmYW1pbHlOYW1lIjoiRG9lIn19fQ
   .
EOS

  CREDENTIAL_CHANGE_REQUIRED = 'https://schemas.openid.net/secevent/risc/event-type/account-credential-change-required'.freeze

  let(:rp_private_key) do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'saml_test_sp.key')),
    )
  end

  let(:jwt) {  }


  # https://openid.net/specs/openid-risc-profile-1_0-ID1.html#rfc.section.5.2
  describe '#create' do
    it 'posts stuff' do
      jwt_payload = {
        iss: identity.service_provider,
        jti: SecureRandom.urlsafe_base64,
        iat: Time.zone.now.to_i,
        aud: api_security_events_url,
        events: {
          CREDENTIAL_CHANGE_REQUIRED => {
            subject: {
              subject_type: 'iss-sub',
              iss: root_url,
              sub: identity.uuid,
            }
          }
        }
      }

      jwt = JWT.encode(jwt_payload, rp_private_key, 'RS256')

      post :create, jwt

      expect(response).to be_accepted
      expect(response.body).to be_empty
    end
  end
end