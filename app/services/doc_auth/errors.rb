module IdentityDocAuth
  module Errors
    # HTTP Status Codes
    IMAGE_LOAD_FAILURE = 'image_load_failure' # 438
    PIXEL_DEPTH_FAILURE = 'pixel_depth_failure' # 439
    IMAGE_SIZE_FAILURE = 'image_size_failure' # 440
    # Alerts
    BARCODE_CONTENT_CHECK = 'barcode_content_check'
    BARCODE_READ_CHECK = 'barcode_read_check'
    BIRTH_DATE_CHECKS = 'birth_date_checks'
    CONTROL_NUMBER_CHECK = 'control_number_check'
    DOC_CROSSCHECK = 'doc_crosscheck'
    DOC_NUMBER_CHECKS = 'doc_number_checks'
    DOCUMENT_EXPIRED_CHECK = 'doc_expired_check' # document has expired
    EXPIRATION_CHECKS = 'expiration_checks' # expiration date valid, expiration crosscheck
    FULL_NAME_CHECK = 'full_name_check'
    GENERAL_ERROR_LIVENESS = 'general_error_liveness'
    GENERAL_ERROR_NO_LIVENESS = 'general_error_no_liveness'
    ID_NOT_RECOGNIZED = 'id_not_recognized'
    ID_NOT_VERIFIED = 'id_not_verified'
    ISSUE_DATE_CHECKS = 'issue_date_checks'
    MULTIPLE_BACK_ID_FAILURES = 'multiple_back_id_failures'
    MULTIPLE_FRONT_ID_FAILURES = 'multiple_front_id_failures'
    REF_CONTROL_NUMBER_CHECK = 'ref_control_number_check'
    SELFIE_FAILURE = 'selfie_failure'
    SEX_CHECK = 'sex_check'
    VISIBLE_COLOR_CHECK = 'visible_color_check'
    VISIBLE_PHOTO_CHECK = 'visible_photo_check'
    # Image metrics
    DPI_LOW_ONE_SIDE = 'dpi_low_one_side'
    DPI_LOW_BOTH_SIDES = 'dpi_low_both_sides'
    SHARP_LOW_ONE_SIDE = 'sharp_low_one_side'
    SHARP_LOW_BOTH_SIDES = 'sharp_low_both_sides'
    GLARE_LOW_ONE_SIDE = 'glare_low_one_side'
    GLARE_LOW_BOTH_SIDES = 'glare_low_both_sides'

    ALL = [
      BARCODE_CONTENT_CHECK,
      BARCODE_READ_CHECK,
      BIRTH_DATE_CHECKS,
      BIRTH_DATE_CHECKS,
      CONTROL_NUMBER_CHECK,
      DOC_CROSSCHECK,
      DOC_NUMBER_CHECKS,
      EXPIRATION_CHECKS,
      FULL_NAME_CHECK,
      GENERAL_ERROR_LIVENESS,
      GENERAL_ERROR_NO_LIVENESS,
      ID_NOT_RECOGNIZED,
      ID_NOT_VERIFIED,
      ISSUE_DATE_CHECKS,
      MULTIPLE_BACK_ID_FAILURES,
      MULTIPLE_FRONT_ID_FAILURES,
      REF_CONTROL_NUMBER_CHECK,
      SELFIE_FAILURE,
      SEX_CHECK,
      VISIBLE_COLOR_CHECK,
      VISIBLE_PHOTO_CHECK,
      DPI_LOW_ONE_SIDE,
      DPI_LOW_BOTH_SIDES,
      SHARP_LOW_ONE_SIDE,
      SHARP_LOW_BOTH_SIDES,
      GLARE_LOW_ONE_SIDE,
      GLARE_LOW_BOTH_SIDES,
    ].freeze
  end
end
