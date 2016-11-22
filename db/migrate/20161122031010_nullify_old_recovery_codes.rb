class NullifyOldRecoveryCodes < ActiveRecord::Migration
  class User < ActiveRecord::Base
  end

  def up
    User.all.each do |user|
      if user.recovery_code.present? && user.recovery_code =~ /^\$2/
        user.update!(recovery_code: nil)
      end
    end
  end

  def down
    # no-op
  end
end
