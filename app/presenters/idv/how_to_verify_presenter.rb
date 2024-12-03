# frozen_string_literal: true

class Idv::HowToVerifyPresenter
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :mobile_required, :selfie_required

  def initialize(mobile_required:, selfie_check_required:)
    @mobile_required = mobile_required
    @selfie_required = selfie_check_required
  end

  def how_to_verify_info
    if mobile_required
      t('doc_auth.info.how_to_verify_selfie')
    else
      t('doc_auth.info.how_to_verify')
    end
  end

  def asset_url
    if mobile_required
      'idv/mobile-phone-icon.svg'
    else
      'idv/remote.svg'
    end
  end

  def alt_text
    if mobile_required
      t('image_description.phone_icon')
    else
      t('image_description.laptop_and_phone')
    end
  end

  def verify_online_text
    if mobile_required
      t('doc_auth.headings.verify_online_selfie')
    else
      t('doc_auth.headings.verify_online')
    end
  end

  def verify_online_instruction
    return t('doc_auth.info.verify_online_instruction_selfie') if selfie_required
    return t('doc_auth.info.verify_online_instruction_mobile_no_selfie') if mobile_required

    t('doc_auth.info.verify_online_instruction')
  end

  def verify_online_description
    if mobile_required
      t('doc_auth.info.verify_online_description_selfie')
    else
      t('doc_auth.info.verify_online_description')
    end
  end

  def submit
    if mobile_required
      t('forms.buttons.continue_remote_selfie')
    else
      t('forms.buttons.continue_remote')
    end
  end

  def post_office_instruction
    if selfie_required
      t('doc_auth.info.verify_at_post_office_instruction_selfie')
    else
      t('doc_auth.info.verify_at_post_office_instruction')
    end
  end

  def post_office_description
    if mobile_required
      t('doc_auth.info.verify_at_post_office_description_selfie')
    else
      t('doc_auth.info.verify_at_post_office_description')
    end
  end
end
