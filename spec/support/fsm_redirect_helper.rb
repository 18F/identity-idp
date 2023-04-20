# Conditionally monkey-patches ApplicationController#redirect_to and calls super
# only in tests if environment variable PRINT_REDIRECTS is set.
# To enable: $ export PRINT_REDIRECTS=true
# $ bundle exec rspec spec/...
# Output looks like:
# Redirected FROM .../app/services/flow/flow_state_machine.rb:170:in `redirect_to_step'
#   TO: "http://127.0.0.1:50654/verify/doc_auth/link_sent"
# To disable: $ unset PRINT_REDIRECTS
# Handy for debugging the Flow State Machine.
class ApplicationController
  if ENV['PRINT_REDIRECTS']
    def redirect_to(options = {}, response_status = {})
      # rubocop:disable Rails/Output
      # rubocop:disable Style/RescueModifier
      puts("Redirected FROM #{caller(1..1).first rescue "unknown"}")
      puts("  TO: #{options.inspect}")
      # rubocop:enable Rails/Output
      # rubocop:enable Style/RescueModifier

      super
    end
  end
end
