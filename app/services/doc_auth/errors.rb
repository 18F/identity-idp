module DocAuth
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
    GENERAL_ERROR = 'general_error'
    ID_NOT_RECOGNIZED = 'id_not_recognized'
    ID_NOT_VERIFIED = 'id_not_verified'
    ISSUE_DATE_CHECKS = 'issue_date_checks'
    MULTIPLE_BACK_ID_FAILURES = 'multiple_back_id_failures'
    MULTIPLE_FRONT_ID_FAILURES = 'multiple_front_id_failures'
    REF_CONTROL_NUMBER_CHECK = 'ref_control_number_check'
    SEX_CHECK = 'sex_check'
    VISIBLE_COLOR_CHECK = 'visible_color_check'
    VISIBLE_PHOTO_CHECK = 'visible_photo_check'
    # Image metrics
    DPI_LOW = 'dpi_low'
    DPI_LOW_FIELD = 'dpi_low_field'
    DPI_LOW_ONE_SIDE = 'dpi_low_one_side'
    DPI_LOW_BOTH_SIDES = 'dpi_low_both_sides'
    SHARP_LOW = 'sharp_low'
    SHARP_LOW_FIELD = 'sharp_low_field'
    SHARP_LOW_ONE_SIDE = 'sharp_low_one_side'
    SHARP_LOW_BOTH_SIDES = 'sharp_low_both_sides'
    GLARE_LOW = 'glare_low'
    GLARE_LOW_FIELD = 'glare_low_field'
    GLARE_LOW_ONE_SIDE = 'glare_low_one_side'
    GLARE_LOW_BOTH_SIDES = 'glare_low_both_sides'
    # Other
    FALLBACK_FIELD_LEVEL = 'fallback_field_level'

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
      GENERAL_ERROR,
      ID_NOT_RECOGNIZED,
      ID_NOT_VERIFIED,
      ISSUE_DATE_CHECKS,
      MULTIPLE_BACK_ID_FAILURES,
      MULTIPLE_FRONT_ID_FAILURES,
      REF_CONTROL_NUMBER_CHECK,
      SEX_CHECK,
      VISIBLE_COLOR_CHECK,
      VISIBLE_PHOTO_CHECK,
      DPI_LOW,
      DPI_LOW_ONE_SIDE,
      DPI_LOW_BOTH_SIDES,
      SHARP_LOW,
      SHARP_LOW_ONE_SIDE,
      SHARP_LOW_BOTH_SIDES,
      GLARE_LOW,
      GLARE_LOW_ONE_SIDE,
      GLARE_LOW_BOTH_SIDES,
      FALLBACK_FIELD_LEVEL,
    ].freeze

    # rubocop:disable Layout/LineLength
    USER_DISPLAY = {
      # Image metrics
      DPI_LOW => { long_msg: DPI_LOW_ONE_SIDE, long_msg_plural: DPI_LOW_BOTH_SIDES, field_msg: DPI_LOW_FIELD },
      SHARP_LOW => { long_msg: SHARP_LOW_ONE_SIDE, long_msg_plural: SHARP_LOW_BOTH_SIDES, field_msg: SHARP_LOW_FIELD },
      GLARE_LOW => { long_msg: GLARE_LOW_ONE_SIDE, long_msg_plural: GLARE_LOW_BOTH_SIDES, field_msg: GLARE_LOW_FIELD },
      # Alerts
      REF_CONTROL_NUMBER_CHECK => { long_msg: REF_CONTROL_NUMBER_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      BARCODE_CONTENT_CHECK => { long_msg: BARCODE_CONTENT_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      BARCODE_READ_CHECK => { long_msg: BARCODE_READ_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      BIRTH_DATE_CHECKS => { long_msg: BIRTH_DATE_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      BIRTH_DATE_CHECKS => { long_msg: BIRTH_DATE_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      CONTROL_NUMBER_CHECK => { long_msg: CONTROL_NUMBER_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ID_NOT_RECOGNIZED => { long_msg: ID_NOT_RECOGNIZED, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      DOC_CROSSCHECK => { long_msg: DOC_CROSSCHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      DOCUMENT_EXPIRED_CHECK => { long_msg: DOCUMENT_EXPIRED_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      DOC_NUMBER_CHECKS => { long_msg: DOC_NUMBER_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      EXPIRATION_CHECKS => { long_msg: EXPIRATION_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      EXPIRATION_CHECKS => { long_msg: EXPIRATION_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      FULL_NAME_CHECK => { long_msg: FULL_NAME_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ISSUE_DATE_CHECKS => { long_msg: ISSUE_DATE_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ISSUE_DATE_CHECKS => { long_msg: ISSUE_DATE_CHECKS, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ID_NOT_VERIFIED => { long_msg: ID_NOT_VERIFIED, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ID_NOT_VERIFIED => { long_msg: ID_NOT_VERIFIED, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      VISIBLE_PHOTO_CHECK => { long_msg: VISIBLE_PHOTO_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ID_NOT_VERIFIED => { long_msg: ID_NOT_VERIFIED, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      SEX_CHECK => { long_msg: SEX_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      VISIBLE_COLOR_CHECK => { long_msg: VISIBLE_COLOR_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      ID_NOT_VERIFIED => { long_msg: ID_NOT_VERIFIED, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      VISIBLE_PHOTO_CHECK => { long_msg: VISIBLE_PHOTO_CHECK, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      # Multiple Errors
      MULTIPLE_FRONT_ID_FAILURES => { long_msg: MULTIPLE_FRONT_ID_FAILURES, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      MULTIPLE_BACK_ID_FAILURES => { long_msg: MULTIPLE_BACK_ID_FAILURES, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
      GENERAL_ERROR => { long_msg: GENERAL_ERROR, field_msg: FALLBACK_FIELD_LEVEL, hints: true },
    }
    # rubocop:enable Layout/LineLength
  end
end
