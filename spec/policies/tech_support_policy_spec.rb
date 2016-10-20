require 'rails_helper'

describe TechSupportPolicy do
  subject { TechSupportPolicy }

  let(:regular_user) { build_stubbed :user }
  let(:privileged_user) { build_stubbed :user, :privileged }
  let(:admin) { build_stubbed :user, :admin }
  let(:tech) { build_stubbed :user, :tech_support }

  shared_examples 'allows_admin_and_tech' do
    it 'allows tech' do
      expect(subject).to permit(tech)
    end

    it 'allows admin' do
      expect(subject).to permit(admin)
    end
  end

  shared_examples 'disallows_non_admin_and_tech' do
    it 'disallows regular_user' do
      expect(subject).not_to permit(regular_user)
    end
  end

  permissions :index? do
    it_behaves_like 'disallows_non_admin_and_tech'

    it_behaves_like 'allows_admin_and_tech'
  end

  permissions :search? do
    it_behaves_like 'disallows_non_admin_and_tech'

    it_behaves_like 'allows_admin_and_tech'
  end

  permissions :show? do
    it_behaves_like 'disallows_non_admin_and_tech'

    it_behaves_like 'allows_admin_and_tech'
  end

  permissions :reset? do
    it_behaves_like 'disallows_non_admin_and_tech'

    it_behaves_like 'allows_admin_and_tech'
  end
end
