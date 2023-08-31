require 'rails_helper'

RSpec.describe VendorOutageController do
  before do
    stub_analytics
  end

  it 'tracks an analytics event' do
    expect_any_instance_of(OutageStatus).to receive(:track_event).with(@analytics)

    get :show
  end

  it 'sets show_gpo_option view variable' do
    get :show

    expect(assigns(:show_gpo_option)).to eq(false)
  end

  context 'from idv phone' do
    before { allow(controller).to receive(:from_idv_phone?).and_return(true) }

    context 'gpo letter available' do
      before { allow(controller).to receive(:gpo_letter_available?).and_return(true) }

      it 'sets show_gpo_option as true' do
        get :show

        expect(assigns(:show_gpo_option)).to eq(true)
      end
    end
  end
end
