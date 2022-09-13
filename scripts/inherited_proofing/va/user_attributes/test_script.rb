#!/usr/bin/env ruby

# Usage
#
# 1) Run with no ARGV and BASE_URI in the Idv::InheritedProofing::Va::Service
#    will default to a base uri of: IdentityConfig.store.inherited_proofing_va_base_url
#    and a private key using: AppArtifacts.store.oidc_private_key
#
# $ bin/rails r scripts/inherited_proofing/va/user_attributes/test_script.rb
#
# 2) To override BASE_URI in the Idv::InheritedProofing::Va::Service class
#    and/or use a private key file:
#
# rubocop:disable Layout/LineLength
# NOTE: Private key files are forced to be located at "#{Rails.root}/tmp".
# $ bin/rails r scripts/inherited_proofing/va/user_attributes/test_script.rb https://staging-api.va.gov private.key
# rubocop:enable Layout/LineLength

require_relative '../../../../app/services/idv/inherited_proofing/va/service'
require_relative '../../../../app/forms/idv/inherited_proofing/va/form'
require_relative '../../errorable'
require_relative './test_server'

raise 'You must run this from the command-line!' unless $PROGRAM_NAME == __FILE__

Scripts::InheritedProofing::Errorable.puts_message "\nTesting call to VA API - START\n\n"

_form, form_response = Scripts::InheritedProofing::Va::UserAttributes::TestServer.new(
  auth_code: 'mocked-auth-code-for-testing',
  base_uri: ARGV[0],
  private_key_file: ARGV[1],
).run

Scripts::InheritedProofing::Errorable.puts_message "Form response:\n\t#{form_response.to_h}"

Scripts::InheritedProofing::Errorable.puts_message "\nTesting call to VA API - END"

Scripts::InheritedProofing::Errorable.puts_message "\nDone."
