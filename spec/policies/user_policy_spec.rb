require 'rails_helper'

describe UserPolicy do
  subject { UserPolicy.new(current_user, user) }

  context 'for a regular user' do
    let(:current_user) { build_stubbed :user }
    let(:user) { build_stubbed :user }

    it { is_expected.to_not permit_action(:index) }
    it { is_expected.to_not permit_action(:show) }
    it { is_expected.to_not permit_action(:update) }
    it { is_expected.to_not permit_action(:edit) }
    it { is_expected.to_not permit_action(:destroy) }
    it { is_expected.to_not permit_action(:reset_password) }
    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'for a tech user' do
    let(:current_user) { build_stubbed :user, :tech_support }
    let(:user) { create :user, :signed_up }

    it { is_expected.to_not permit_action(:index) }
    it { is_expected.to_not permit_action(:show) }
    it { is_expected.to_not permit_action(:update) }
    it { is_expected.to_not permit_action(:edit) }
    it { is_expected.to_not permit_action(:destroy) }
    it { is_expected.to_not permit_action(:reset_password) }

    it { is_expected.to permit_action(:tech_reset_password) }
  end

  context 'for an admin user' do
    let(:current_user) { build_stubbed :user, :admin }
    let(:user) { create :user, :signed_up }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:reset_password) }
    it { is_expected.to permit_action(:tech_reset_password) }
  end

  context 'when regular user is same as current_user' do
    let(:current_user) { build_stubbed :user, :signed_up }
    let(:user) { current_user }

    it { is_expected.to_not permit_action(:destroy) }
    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when admin user is same as current_user' do
    let(:current_user) { build_stubbed :user, :admin }
    let(:user) { current_user }

    it { is_expected.to_not permit_action(:destroy) }
    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when tech user is same as current_user' do
    let(:current_user) { build_stubbed :user, :tech_support }
    let(:user) { current_user }

    it { is_expected.to_not permit_action(:destroy) }
    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when admin tries to reset another admin' do
    let(:current_user) { build_stubbed :user, :admin }
    let(:user) { build_stubbed :user, :admin }

    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when admin tries to reset a tech' do
    let(:current_user) { build_stubbed :user, :admin }
    let(:user) { build_stubbed :user, :tech_support }

    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when tech tries to reset another tech' do
    let(:current_user) { build_stubbed :user, :tech_support }
    let(:user) { build_stubbed :user, :tech_support }

    it { is_expected.to_not permit_action(:tech_reset_password) }
  end

  context 'when tech tries to reset an admin' do
    let(:current_user) { build_stubbed :user, :tech_support }
    let(:user) { build_stubbed :user, :admin }

    it { is_expected.to_not permit_action(:tech_reset_password) }
  end
end
