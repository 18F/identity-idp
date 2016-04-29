require 'rails_helper'

describe AppSettingPolicy do
  subject { AppSettingPolicy }

  let(:current_user) { FactoryGirl.build_stubbed :user }
  let(:other_user) { FactoryGirl.build_stubbed :user }
  let(:tech_support_user) { FactoryGirl.build_stubbed :user, :tech_support }
  let(:admin) { FactoryGirl.build_stubbed :user, :admin }

  permissions :index? do
    it 'denies access if not an admin' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access for a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'allows access for an admin' do
      expect(subject).to permit(admin)
    end
  end

  permissions :show? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'permits admin user' do
      expect(subject).to permit(admin)
    end
  end

  permissions :update? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'permits admin user' do
      expect(subject).to permit(admin)
    end
  end

  permissions :edit? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'permits admin user' do
      expect(subject).to permit(admin)
    end
  end

  permissions :destroy? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'denies admin user' do
      expect(subject).not_to permit(admin)
    end
  end

  permissions :create? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'permits admin user' do
      expect(subject).to permit(admin)
    end
  end

  permissions :new? do
    it 'denies access if a user' do
      expect(subject).not_to permit(current_user)
    end
    it 'denies access if a tech support user' do
      expect(subject).not_to permit(tech_support_user)
    end
    it 'permits admin user' do
      expect(subject).to permit(admin)
    end
  end
end
