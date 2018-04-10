require 'rails_helper'

describe ChangePhoneEvent do
  it { is_expected.to belong_to(:user) }
end
