require 'rails_helper'

describe Agency do
  describe 'validations' do
    let(:agency) { build_stubbed(:agency) }

    it { is_expected.to validate_presence_of(:name) }
  end
end
