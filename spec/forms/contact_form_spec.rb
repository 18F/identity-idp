require 'rails_helper'

describe ContactForm do
  it do
    is_expected.
      to validate_presence_of(:email_or_tel).with_message("can't be blank")
  end
end
