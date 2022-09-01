#!/usr/bin/env ruby

# Usage
#
# 1) Run with no ARGV and BASE_URI in the Idv::InheritedProofing::Va::Service
#    will default to: IdentityConfig.store.inherited_proofing_va_base_url.
#
# $ rails r scripts/inherited-proofing-va-test.rb

# 2) To override BASE_URI in the Idv::InheritedProofing::Va::Service class:
#
# $ rails r scripts/inherited-proofing-va-test.rb https://localhost:3000

require_relative '../app/services/idv/inherited_proofing/va/service'
require_relative '../app/forms/idv/inherited_proofing/va/form'

module Errorable
  module_function

  def puts_message(message)
    puts message
  end

  def puts_success(message)
    puts_message "Success: #{message}"
  end

  def puts_error(message)
    puts_message "Oops! An error occurred: #{message}"
  end
end

class VaInheritedProofingTester < Idv::InheritedProofing::Va::Service
  include Errorable

  attr_reader :base_uri

  def initialize(auth_code:, base_uri: nil)
    super auth_code

    @base_uri = base_uri || BASE_URI
  end

  def run
    begin
      # rubocop:disable Layout/LineLength
      puts_message "Retrieving the user's PII from the VA using auth code: '#{auth_code}' at #{request_uri}..."
      puts_message "Retrieved payload containing the user's PII from the VA:\n\tRetrieved user PII: #{user_pii}"
      # rubocop:enable Layout/LineLength

      puts_message "Validating payload containing the user's PII from the VA..."
      if form_response.success?
        puts_success "Retrieved user PII is valid:\n\t#{user_pii}"
      else
        puts_error "Payload returned from the VA is invalid:\n\t#{form.errors.full_messages}"
      end
    rescue => e
      puts_error e.message
    end
  end

  private

  # Override
  def request_uri
    @request_uri ||= "#{ URI(@base_uri) }/inherited_proofing/user_attributes"
  end

  def user_pii
    @user_pii ||= execute
  end

  def form_response
    @form_response ||= Idv::InheritedProofing::Va::Form.new(payload_hash: user_pii).submit
  end
end

raise 'You must run this from the command-line!' unless $PROGRAM_NAME == __FILE__

Errorable.puts_message "\nTesting call to VA API - START\n\n"

VaInheritedProofingTester.new(auth_code: 'mocked-auth-code-for-testing', base_uri: ARGV[0]).run

Errorable.puts_message "\nTesting call to VA API - END"

Errorable.puts_message "\nDone."
