require 'rails_helper'

RSpec.describe Agreements::AgencyBlueprint do
  let(:agency) do
    create(:agency, abbreviation: 'ABC', name: 'Awesome Bureau of Comedy')
  end
  let(:expected) do
    {
      agencies: [
        {
          abbreviation: 'ABC',
          name: 'Awesome Bureau of Comedy',
        },
      ],
    }.to_json
  end

  it 'renders the appropriate json' do
    expect(described_class.render([agency], root: :agencies)).to eq(expected)
  end
end
