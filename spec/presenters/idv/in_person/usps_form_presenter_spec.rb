require 'rails_helper'

RSpec.describe Idv::InPerson::UspsFormPresenter do
  subject(:presenter) { Idv::InPerson::UspsFormPresenter.new }

  it 'does not include territories that cause usps api to error' do
    expect(
      presenter.usps_states_territories.map do |_name, abbrev|
        abbrev
      end,
    ).not_to include('AA', 'AE', 'AP', 'UM')
  end
end
