require 'rails_helper'

describe AhoyEvent do
  subject { AhoyEvent.new }

  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to belong_to(:user) }
end
