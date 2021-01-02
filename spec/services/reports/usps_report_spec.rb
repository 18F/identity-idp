require 'rails_helper'

describe Reports::UspsReport do
  subject { described_class }
  let(:empty_report) do
    {
      'letters_sent_and_validated_since_days' => {
        '10000'=>0, '14'=>0, '30'=>0, '60'=>0, '7'=>0, '90'=>0
      },
      'letters_sent_since_days' => {
        '10000'=>0, '14'=>0, '30'=>0, '60'=>0, '7'=>0, '90'=>0
      },
      'percent_sent_and_validated_since_days' => {
        '10000'=>0, '14'=>0, '30'=>0, '60'=>0, '7'=>0, '90'=>0
      },
      'today' => Time.zone.today.to_s,
    }
  end

  it 'is empty' do
    expect(JSON.parse(subject.new.call)).to eq(empty_report)
  end
end
