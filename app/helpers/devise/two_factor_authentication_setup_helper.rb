module Devise
  module TwoFactorAuthenticationSetupHelper
    def second_factor_checkboxes_for(f, form_location = '')
      f.collection_check_boxes(
        :second_factor_ids, SecondFactor.all, :id, :name,
        item_wrapper_tag: :div, checked: checked_state(f, form_location)
      ) do |b|
        id = id_for_2fa_checkbox(b)
        b.label(for: id) { b.check_box(id: id) + b.text }
      end
    end

    def id_for_2fa_checkbox(checkbox)
      "user_second_factor_ids_#{checkbox.object.name.downcase}"
    end

    def checked_state(f, form_location)
      return SecondFactor.pluck(:id) if form_location == '2fa_setup'
      f.object.second_factor_ids
    end
  end
end
