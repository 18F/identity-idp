class NonexistentUser
  def uuid
    'nonexistent-uuid'
  end

  def confirmed?
    false
  end

  def persisted?
    false
  end

  def active_profile
    nil
  end
end
