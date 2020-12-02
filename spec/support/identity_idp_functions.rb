require 'identity-idp-functions'

module IdentityIdpFunctions
  module LoggingHelper
    # prevent console noise in specs
    def default_logger_io
      '/dev/null'
    end
  end
end
