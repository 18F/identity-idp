# frozen_string_literal: true

require_relative '../../spec/support/features/idv_helper'
require_relative '../../spec/support/features/personal_key_helper'
require_relative '../../spec/support/features/session_helper'
require_relative '../../spec/support/otp_helper'

World(
  ActionView::Helpers::TranslationHelper,
  Features::SessionHelper,
  IdvHelper,
  OtpHelper,
)
