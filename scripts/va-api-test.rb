#!/usr/bin/env ruby

require 'jwt'
require 'jwe'
require 'net/http'

# Script to test connection to VA API, can be removed once we create code inside the IDV flow
class VaApiTest
  def run
    uri = URI 'https://staging-api.va.gov/inherited_proofing/user_attributes'
    headers = { Authorization: "Bearer #{jwt_token}" }

    response = Net::HTTP.get_response(uri, headers)
    decrypt_payload(response)
  end

  private

  def jwt_token
    payload = { inherited_proofing_auth: 'mocked-auth-code-for-testing', exp: 1.day.from_now.to_i }
    JWT.encode(payload, private_key, 'RS256')
  end

  def decrypt_payload(response)
    payload = JSON.parse(response.body)['data']
    JWE.decrypt(payload, private_key) if payload
  end

  def private_key
    return AppArtifacts.store.oidc_private_key if private_key_store?

    OpenSSL::PKey::RSA.new(File.read(private_key_file))
  end

  # Returns true if a private key store should be used
  # (as opposed to the private key file).
  def private_key_store?
    Identity::Hostdata.in_datacenter? || !private_key_file?
  end

  def private_key_file?
    File.exist?(private_key_file)
  end

  def private_key_file
    @private_key_file ||= 'tmp/va_ip.key'
  end
end

puts(VaApiTest.new.run || 'VaApiTest#run returned no output') if $PROGRAM_NAME == __FILE__
