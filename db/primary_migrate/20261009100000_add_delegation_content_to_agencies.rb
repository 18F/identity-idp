# frozen_string_literal: true

# Agency-level consent content for delegated access. When a service provider asks to act for the
# user at one of the agency's applications, the consent screen groups the applications under the
# agency and shows what the agency says about itself: a short localized description and a page to
# learn more, next to the name and logo the agency already has.
#
# The two version counters let the agency edit its text regularly without re-asking every person
# for every edit: `consent_content_version` increments on each edit, and
# `consent_material_version` is set equal to it only when the editor marks the edit as a material
# change. A remembered approval stays current while the version it recorded is at or above the
# material version.
#
# The content is loaded from the delegated-access configuration file by `DelegatedAccessSeeder`
# in every environment; the partner Dashboard (identity-dashboard) does not have these fields.
class AddDelegationContentToAgencies < ActiveRecord::Migration[8.1]
  def change
    # Localized plain text keyed by locale ({ "en" => "...", "es" => "..." }); never HTML.
    add_column :agencies, :delegation_description, :jsonb, default: {}, null: false,
                                                           comment: 'sensitive=false'
    add_column :agencies, :delegation_learn_more_url, :text, comment: 'sensitive=false'
    add_column :agencies, :consent_content_version, :integer, default: 1, null: false,
                                                              comment: 'sensitive=false'
    add_column :agencies, :consent_material_version, :integer, default: 1, null: false,
                                                               comment: 'sensitive=false'
  end
end
