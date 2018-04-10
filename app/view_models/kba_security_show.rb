class KbaSecurityShow
  AGENCIES = [
    ['CBP Trusted Traveler Programs', 1],
    ['USA JOBS', 2],
    ['Railroad Retirement Board', 3],
    ['NSG Open Mapping Enclave', 4],
  ].freeze

  def self.answers
    arr = []
    arr << [I18n.t('kba_security.dropdown_message'), -1]
    arr.concat(AGENCIES)
    arr << [I18n.t('kba_security.dropdown_other'), 0]
    arr
  end
end
