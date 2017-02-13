class PhoneNew
  def initialize(modal: nil)
    @modal = modal
  end

  def title
    I18n.t('idv.titles.phone')
  end

  def modal_type
    modal
  end

  def modal_partial
    if modal.present?
      'shared/modal_verification'
    else
      'shared/null'
    end
  end

  private

  attr_reader :modal
end
