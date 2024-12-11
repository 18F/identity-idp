# frozen_string_literal: true

require_relative '../../spec/support/features/idv_helper'
require_relative '../../spec/support/features/personal_key_helper'
require_relative '../../spec/support/features/session_helper'
require_relative '../../spec/support/otp_helper'
require_relative '../../spec/support/features/in_person_helper'
require_relative '../../spec/support/features/strip_tags_helper'

World(
  ActionView::Helpers::TranslationHelper,
  FactoryBot::Syntax::Methods,
  Features::SessionHelper,
  Features::StripTagsHelper,
  IdvHelper,
  InPersonHelper,
  OtpHelper,
)
