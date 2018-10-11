class NonexistentUser
  def uuid
    'nonexistent-uuid'
  end

  def role
    'nonexistent'
  end

  def confirmed?
    false
  end

  def persisted?
    false
  end

  def admin?
    false
  end

  def tech?
    false
  end

  def active_profile
    nil
  end
end
