##
# This initializer is present to force an upgrade from the `acuant_simulator`
# config to the `doc_auth_vendor` config. It can be removed after a deploy
# cycle where everyone has had a chance to upgrade to the new config.
#
# Flipping the FORCE_ACUANT_CONFIG_UPGRADE below will require prevent the app
# from starting if the acuant simulator is enabled but the mock doc auth vendor
# vendor is not turned on.
#
FORCE_ACUANT_CONFIG_UPGRADE = true

if AppConfig.env.acuant_simulator == 'true' &&
   AppConfig.env.doc_auth_vendor != 'mock'

  error_message = <<~HEREDOC
    The `acuant_simulator` config has been retired in favor of `doc_auth_vendor`.

    You are seeing this because you have `acuant_simulator` set to 'true' but
    you have not updated `doc_auth_vendor` to 'mock'.

    If you do not want Acuant enabled, remove the `acuant_simulator` config and
    set the `doc_auth_vendor` config to 'mock'. Currently `acuant_simulator` is
    set to 'true'. Making this change will maintain the current behavior.

    If you want Acuant enabled, remove the `acuant_simulator` and config set the
    `doc_auth_vendor` config to 'acuant'. Currently `acuant_simulator` is set to
    'true'. Making this change will change the current behavior.
  HEREDOC

  # rubocop:disable Style/GuardClause
  if FORCE_ACUANT_CONFIG_UPGRADE
    raise error_message
  else
    warn error_message
  end
  # rubocop:enable Style/GuardClause
end
