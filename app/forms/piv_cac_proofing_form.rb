class PivCacProofingForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :x509_issuer, :token, :error_type, :nonce, :user, :key_id,
                :first_name, :last_name, :cn

  validates :token, presence: true
  validates :nonce, presence: true

  def submit
    success = valid? && valid_submission?

    errors = error_type ? { type: error_type } : {}
    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes.merge(error_type ? { key_id: key_id } : {}),
    )
  end

  def card_type
    return unless @data
    @data['card_type']
  end

  private

  def valid_submission?
    valid_token? && valid_full_name_or_cn?
  end

  def valid_full_name_or_cn?
    return if @data.nil? || @data['card_type'].blank?
    @cn = PivCac::ExtractCnFromSubject.call(@data['subject'])
    return if cn.blank?
    @last_name, @first_name = cn.split('.') if card_type == 'cac'
    true
  end

  def extra_analytics_attributes
    {
      step: 'present_cac',
      card_type: card_type,
      cn_present: cn.present?,
      cn_format: PivCac::SanitizeCn.call(cn.to_s),
      cac_first_name_present: first_name.present?,
      cac_last_name_present: last_name.present?,
    }
  end
end
