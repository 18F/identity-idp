# frozen_string_literal: true

class TwoFactorLoginOptionsForm
  include ActiveModel::Model

  attr_reader :selection
  attr_reader :configuration_id

  validates :selection, inclusion: { in: %w[voice sms auth_app piv_cac personal_key
                                            webauthn webauthn_platform backup_code] }

  def initialize(user)
    self.user = user
  end

  def submit(params)
    self.selection, self.configuration_id = selection_and_configuration_id(params)

    success = valid?

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_writer :selection
  attr_writer :configuration_id

  def selection_and_configuration_id(params)
    selection = params[:selection]
    configuration_id = nil
    if selection =~ /(.+)[:_](\d+)/
      selection = Regexp.last_match(1)
      configuration_id = Regexp.last_match(2)
    end
    [selection, configuration_id]
  end

  def mfa_context
    MfaContext.new(user)
  end

  def extra_analytics_attributes
    {
      selection: selection,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
    }
  end
end
