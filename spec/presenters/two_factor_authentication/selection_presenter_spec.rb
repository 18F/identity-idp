require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SelectionPresenter do
  subject(:presenter) { described_class.new }

  describe '#disabled?' do
    it { expect(presenter.disabled?).to eq(false) }
  end
end
