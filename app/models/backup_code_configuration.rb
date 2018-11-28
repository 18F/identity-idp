class BackupCodeConfiguration < ApplicationRecord
  belongs_to :user

  def self.unused
    where(used: false)
  end

  def mfa_enabled?
    used == false
  end

  def selection_presenters
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
  end

  def friendly_name
    :backup_codes
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end
end
