# frozen_string_literal: true

D = Steep::Diagnostic
#
# target :lib do
#   signature "sig"
#   ignore_signature "sig/test"
#
#   check "lib"                       # Directory name
#   check "path/to/source.rb"         # File name
#   check "app/models/**/*.rb"        # Glob
#   # ignore "lib/templates/*.rb"
#
#   # library "pathname"              # Standard libraries
#   # library "strong_json"           # Gems
#
#   # configure_code_diagnostics(D::Ruby.default)
#   #   # `default` diagnostics setting (applies by default)
#   # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
#   # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
#   # configure_code_diagnostics(D::Ruby.silent)       # `silent` diagnostics setting
#   # configure_code_diagnostics do |hash|             # You can setup everything yourself
#   #   hash[D::Ruby::NoMethod] = :information
#   # end
# end

# target :test do
#   unreferenced!
#   # Skip type checking the `lib` code when types in `test` target is changed
#   signature "sig/test"              # Put RBS files for tests under `sig/test`
#   check "test"                      # Type check Ruby scripts under `test`
#
#   configure_code_diagnostics(D::Ruby.lenient)      # Weak type checking for test code
#
#   # library "pathname"              # Standard libraries
# end

# target :app do
#   check 'app/forms/delete_user_email_form.rb'
#   signature 'sig'
#   configure_code_diagnostics(D::Ruby.strict)

#   library 'pathname'
# end

target :app do
  check 'app/forms/select_email_form.rb'
  signature 'sig'
  configure_code_diagnostics(D::Ruby.strict)

  library 'pathname'
end

target :app do
  check 'app/controllers/accounts/connected_accounts/selected_email_controller.rb'
  signature 'sig'
  # configure_code_diagnostics(D::Ruby.strict)

  library 'pathname'
end
