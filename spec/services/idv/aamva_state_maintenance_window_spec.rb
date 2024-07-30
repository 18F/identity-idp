require 'rails_helper'

RSpec.describe Idv::AamvaStateMaintenanceWindow do

  subject { described_class.in_maintenance_window?(state) }

  before do
    allow(IdentityConfig.store).to receive(:aamva_state_daily_maintenance_windows).and_return(
      {
        "DC"=>{"start_time"=>"00:00", "end_time"=>"06:00", "tz"=>"America/New_York"},
        "KY"=>{"start_time"=>"02:50", "end_time"=>"06:40", "tz"=>"America/New_York"},
      }
    )
  end

  describe "#in_maintenance_window?" do
    let(:state) { "DC" }


    context "for a state with a defined outage window" do
      it 'is true during the maintenance window' do
        travel_to(Time.parse("today 02:00")) do
          expect(subject).to eq(true)
        end
      end

      it 'is false outside of the maintenance window' do
        travel_to(Time.parse("today 08:00")) do
          expect(subject).to eq(false)
        end
      end
    end

    context "for a state without a defined outage window" do
      let(:state) { "LG" }

      it 'returns false without an exception' do
        expect(subject).to eq(false)
      end
    end
  end
end
