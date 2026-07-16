# frozen_string_literal: true

module AccountsHelper
  # Fallback monogram for an agency/service logo circle: up to three uppercase
  # letters/digits from the name (e.g. "Internal Revenue Service" -> "IRS"),
  # else the first two characters upcased. Shared by the connected-services and
  # discovery row partials so the fallback stays identical.
  def agency_initials(name)
    name = name.to_s
    name.scan(/[A-Z0-9]/).first(3).join.presence || name.first(2).upcase
  end
end
