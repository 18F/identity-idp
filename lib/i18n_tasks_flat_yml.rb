# frozen_string_literal: true

require_relative './i18n_flat_yml_backend'

module I18nTasksFlatYml
  module FileFormatsOverrides
    def load_file(path)
      content = super

      if I18nFlatYmlBackend.nested_hashes?(content)
        content
      else
        {
          I18nFlatYmlBackend.locale(path) => I18nFlatYmlBackend.unflatten(content),
        }
      end
    end
  end
end

module I18n
  module Tasks
    module Data
      module FileFormats
        # We need to override this because the adapter doesn't pass the filename,
        # which we need to properly set the locale of the strings
        prepend I18nTasksFlatYml::FileFormatsOverrides
      end
    end
  end
end
