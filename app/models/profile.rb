class Profile < ActiveRecord::Base
  belongs_to :user

  validates_uniqueness_of :active, scope: :user_id, if: :active?

  # rubocop:disable AbcSize, MethodLength
  def self.create_from_proofer_applicant(applicant, user)
    create(
      user: user,
      first_name: applicant.first_name,
      middle_name: applicant.middle_name,
      last_name: applicant.last_name,
      address1: applicant.address1,
      address2: applicant.address2,
      city: applicant.city,
      state: applicant.state,
      zipcode: applicant.zipcode,
      dob: applicant.dob,
      ssn: applicant.ssn,
      phone: applicant.phone
    )
  end
  # rubocop:enable AbcSize, MethodLength

  def activate
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: Time.zone.now)
    end
  end

  def verified?
    verified_at.present?
  end
end
