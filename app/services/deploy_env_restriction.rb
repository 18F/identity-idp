# frozen_string_literal: true

# Decides whether an entry of a seed file (a service provider or an agency) belongs in the
# current environment. An entry may carry `restrict_to_deploy_env`, read only when the Rails
# environment is production; in development and test every entry is written.
#
#   restrict_to_deploy_env: 'prod'     written in prod only
#   restrict_to_deploy_env: 'staging'  written in staging only
#   restrict_to_deploy_env: 'sandbox'  written in every deployed environment except prod and
#                                      staging (dev, int, personal sandboxes, review apps)
#   absent or blank                    written everywhere except prod
class DeployEnvRestriction
  def initialize(rails_env:, deploy_env:)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  def allows?(config)
    return true if rails_env != 'production'

    restrict_env = config['restrict_to_deploy_env']
    in_prod = deploy_env == 'prod'
    in_staging = deploy_env == 'staging'
    in_sandbox = !in_prod && !in_staging

    return true if restrict_env == 'prod' && in_prod
    return true if restrict_env == 'staging' && in_staging
    return true if restrict_env == 'sandbox' && in_sandbox
    return true if restrict_env.blank? && !in_prod

    false
  end

  private

  attr_reader :rails_env, :deploy_env
end
