# frozen_string_literal: true

class Idv::HowToVerifyPresenter
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :mobile_required, :selfie_required, :passport_allowed

  def initialize(mobile_required:, selfie_check_required:, passport_allowed:)
    @mobile_required = mobile_required
    @selfie_required = selfie_check_required
    @passport_allowed = passport_allowed
  end

  def how_to_verify_info
    t('doc_auth.headings.how_to_verify')
  end

  def header_text
    t('doc_auth.headings.how_to_verify')
  end

  def hybrid_handoff_text
    if selfie_required
      t('doc_auth.info.hybrid_handoff_selfie')
    else
      t('doc_auth.info.hybrid_handoff_no_selfie')
    end
  end

  def online_asset_url
    'idv/mobile-phone-icon.svg'
  end

  def online_asset_alt_text
    if mobile_required
      t('image_description.phone_icon')
    else
      t('image_description.laptop_and_phone')
    end
  end

  def verify_online_text
    t('doc_auth.headings.verify_online')
  end

  def verify_online_instruction
    return t('doc_auth.info.verify_online_instruction_selfie') if selfie_required

    t('doc_auth.info.verify_online_instruction')
  end

  def verify_online_description
    if passport_allowed
      t('doc_auth.info.verify_online_description_passport')
    else
      ''
    end
  end

  def online_submit
    t('forms.buttons.continue_online')
  end

  def post_office_asset_url
    'idv/in-person.svg'
  end

  def post_office_asset_alt_text
    t('image_description.post_office')
  end

  def verify_at_post_office_text
    t('doc_auth.headings.verify_at_post_office')
  end

  def post_office_instruction
    t('doc_auth.info.verify_at_post_office_instruction')
  end

  def post_office_accepted_id_instruction
    t('doc_auth.info.verify_at_post_office_instruction')
  end

  def post_office_description
    if passport_allowed
      IdentityConfig.store.in_person_passports_enabled ?
      t('doc_auth.info.verify_online_description_passport') :
      t('doc_auth.info.verify_at_post_office_description_passport_html')
    else
      ''
    end
  end

  def post_office_submit
    t('forms.buttons.continue_ipp')
  end
end
