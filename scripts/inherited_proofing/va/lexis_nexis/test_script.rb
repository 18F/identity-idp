#!/usr/bin/env ruby

# rubocop:disable Layout/LineLength

# Usage
#
# 1) Run with no ARGV and BASE_URI in the Idv::InheritedProofing::Va::Service
#    will default to a base uri of: IdentityConfig.store.inherited_proofing_va_base_url
#    and a private key using: AppArtifacts.store.oidc_private_key
#
# $ bin/rails r scripts/inherited_proofing/va/lexis_nexis/test_script.rb
#
# 2) To override BASE_URI in the Idv::InheritedProofing::Va::Service class
#    and/or use a private key file, and/or force an error return.
#    Where -u|-t|-f forces proofing to fail
#
# NOTE: Private key files are forced to be located at "#{Rails.root}/tmp".
# $ bin/rails r scripts/inherited_proofing/va/lexis_nexis/test_script.rb https://staging-api.va.gov private.key -u|-t|-f

require_relative '../user_attributes/test_server'
require_relative './phone_finder'
require_relative '../../errorable'

def error_phone_or_default(fail_option:, default_phone:)
  return case fail_option
  when '-u'
    Scripts::InheritedProofing::Errorable.puts_message "Forcing unverifiable phone number failure (#{fail_option})"
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  when '-t'
    Scripts::InheritedProofing::Errorable.puts_message "Forcing proofer timeout failure (#{fail_option})"
    Proofing::Mock::AddressMockClient::PROOFER_TIMEOUT_PHONE_NUMBER
  when '-f'
    Scripts::InheritedProofing::Errorable.puts_message "Forcing failed to contact phone number (#{fail_option})"
    Proofing::Mock::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER
  else
    default_phone
  end
end

raise 'You must run this from the command-line!' unless $PROGRAM_NAME == __FILE__

Scripts::InheritedProofing::Errorable.puts_message "\nTesting call to Lexis Nexis Phone Finder - START"

form, form_response = Scripts::InheritedProofing::Va::UserAttributes::TestServer.new(
  auth_code: 'mocked-auth-code-for-testing',
  base_uri: ARGV[0],
  private_key_file: ARGV[1],
).run

Scripts::InheritedProofing::Errorable.puts_message "Form response:\n\t#{form_response.to_h}"

user_pii = form.payload_hash
user_pii[:uuid] = SecureRandom.uuid
# Lexis Nexis Phone Finder expects dob (as opposed to birth_date).
user_pii[:dob] = user_pii.delete(:birth_date)
user_pii[:phone] = error_phone_or_default fail_option: ARGV[2], default_phone: user_pii[:phone]
user_pii.delete(:address)
user_pii.delete(:mhv_data)

Scripts::InheritedProofing::Errorable.puts_message "Calling Lexis Nexis Phone Finder using:\n\t#{user_pii}}"

# Verify the user's pii.
address_proofer_results = Scripts::InheritedProofing::Va::LexisNexis::PhoneFinder.call(user_pii)

Scripts::InheritedProofing::Errorable.puts_message "Call to Lexis Nexis Phone Finder complete. Results:\n\t#{address_proofer_results.to_h}"

Scripts::InheritedProofing::Errorable.puts_message "\nTesting call to Lexis Nexis Phone Finder - END"

Scripts::InheritedProofing::Errorable.puts_message "\nDone."
# rubocop:enable Layout/LineLength
