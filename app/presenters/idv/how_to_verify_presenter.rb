class Idv::HowToVerifyPresenter
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :idv_session

  def initialize(selfie_check_required:)
    @selfie_required = selfie_check_required
  end

  def how_to_verify_info
    if @selfie_required
      t('doc_auth.info.how_to_verify_selfie')
    else
      t('doc_auth.info.how_to_verify')
    end
  end

  def asset_url
    if @selfie_required
      'idv/mobile-phone-icon.svg'
    else
      'idv/remote.svg'
    end
  end

  def alt_text
    if @selfie_required
      t('image_description.phone_icon')
    else
      t('image_description.laptop_and_phone')
    end
  end

  def verify_online_text
    if @selfie_required
      t('doc_auth.headings.verify_online_selfie')
    else
      t('doc_auth.headings.verify_online')
    end
  end

  def verify_online_instruction
    if @selfie_required
      t('doc_auth.info.verify_online_instruction_selfie')
    else
      t('doc_auth.info.verify_online_instruction')
    end
  end

  def verify_online_description
    if @selfie_required
      t('doc_auth.info.verify_online_description_selfie')
    else
      t('doc_auth.info.verify_online_description')
    end
  end

  def submit
    if @selfie_required
      t('forms.buttons.continue_remote_selfie')
    else
      t('forms.buttons.continue_remote')
    end
  end

  def post_office_instruction
    if @selfie_required
      t('doc_auth.info.verify_at_post_office_instruction_selfie')
    else
      t('doc_auth.info.verify_at_post_office_instruction')
    end
  end

  def post_office_description
    if @selfie_required
      t('doc_auth.info.verify_at_post_office_description_selfie')
    else
      t('doc_auth.info.verify_at_post_office_description')
    end
  end
end
