window.LoginGov = window.LoginGov || {};



window.LoginGov.I18n = {
  currentLocale: function() { return this.__currentLocale || (this.__currentLocale = document.querySelector('html').lang); },
  strings: {},
  t: function(key) { return this.strings[this.currentLocale()][key]; },
  key: function(key) { return key.replace(/[ -]/g, '_').replace(/\W/g, '').toLowerCase(); }
};

  window.LoginGov.I18n.strings['en'] = {};
  
    window.LoginGov.I18n.strings['en']['two_factor_authentication.otp_delivery_preference.instruction'] = 'You can change this selection the next time you log in. If you entered a landline, please select \"Phone call\" below.';
  
    window.LoginGov.I18n.strings['en']['two_factor_authentication.otp_delivery_preference.phone_unsupported'] = 'We\'re unable to make phone calls to people in %{location} at this time.';
  
    window.LoginGov.I18n.strings['en']['errors.messages.format_mismatch'] = 'Please match the requested format.';
  
    window.LoginGov.I18n.strings['en']['errors.messages.missing_field'] = 'Please fill in this field.';
  
    window.LoginGov.I18n.strings['en']['forms.passwords.show'] = 'Show password';
  
    window.LoginGov.I18n.strings['en']['idv.errors.pattern_mismatch.dob'] = 'Your date of birth must be entered in as mm/dd/yyyy';
  
    window.LoginGov.I18n.strings['en']['idv.errors.pattern_mismatch.personal_key'] = 'Please enter your personal key for this account. Example: ABC1-DEF2-G3HI-J456';
  
    window.LoginGov.I18n.strings['en']['idv.errors.pattern_mismatch.ssn'] = 'Your Social Security Number must be entered in as ###-##-####';
  
    window.LoginGov.I18n.strings['en']['idv.errors.pattern_mismatch.state_id_number'] = 'Your ID number cannot be more than 25 characters.';
  
    window.LoginGov.I18n.strings['en']['idv.errors.pattern_mismatch.zipcode'] = 'Your zipcode must be entered in as #####-####';
  
    window.LoginGov.I18n.strings['en']['idv.failure.button.warning'] = 'Try again';
  
    window.LoginGov.I18n.strings['en']['instructions.password.strength.i'] = 'Very weak';
  
    window.LoginGov.I18n.strings['en']['instructions.password.strength.ii'] = 'Weak';
  
    window.LoginGov.I18n.strings['en']['instructions.password.strength.iii'] = 'So-so';
  
    window.LoginGov.I18n.strings['en']['instructions.password.strength.iv'] = 'Good';
  
    window.LoginGov.I18n.strings['en']['instructions.password.strength.v'] = 'Great!';
  
    window.LoginGov.I18n.strings['en']['simple_form.required.text'] = 'This field is required';
  
    window.LoginGov.I18n.strings['en']['valid_email.validations.email.invalid'] = 'Invalid email address format or domain entered. Please enter a valid email address.';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.a_word_by_itself_is_easy_to_guess'] = 'A word by itself is easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better'] = 'Add another word or two. Uncommon words are better';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.all_uppercase_is_almost_as_easy_to_guess_as_all_lowercase'] = 'All-uppercase is almost as easy to guess as all-lowercase';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.avoid_dates_and_years_that_are_associated_with_you'] = 'Avoid dates and years that are associated with you';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.avoid_recent_years'] = 'Avoid recent years';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.avoid_repeated_words_and_characters'] = 'Avoid repeated words and characters';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.avoid_sequences'] = 'Avoid sequences';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.avoid_years_that_are_associated_with_you'] = 'Avoid years that are associated with you';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.capitalization_doesnt_help_very_much'] = 'Capitalization doesn’t help very much';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.common_names_and_surnames_are_easy_to_guess'] = 'Common names and surnames are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.dates_are_often_easy_to_guess'] = 'Dates are often easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.names_and_surnames_by_themselves_are_easy_to_guess'] = 'Names and surnames by themselves are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.there_is_no_need_for_symbols_digits_or_uppercase_letters'] = 'There is no need for symbols, digits, or uppercase letters';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.predictable_substitutions_like__instead_of_a_dont_help_very_much'] = 'Predictable substitutions like \'@\' instead of \'a\' don’t help very much';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.recent_years_are_easy_to_guess'] = 'Recent years are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.repeats_like_aaa_are_easy_to_guess'] = 'Repeats like \"aaa\" are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.repeats_like_abcabcabc_are_only_slightly_harder_to_guess_than_abc'] = 'Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.reversed_words_arent_much_harder_to_guess'] = 'Reversed words aren’t much harder to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.sequences_like_abc_or_6543_are_easy_to_guess'] = 'Sequences like abc or 6543 are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.short_keyboard_patterns_are_easy_to_guess'] = 'Short keyboard patterns are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.straight_rows_of_keys_are_easy_to_guess'] = 'Straight rows of keys are easy to guess';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.this_is_a_top_10_common_password'] = 'This is a top-10 common password';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.this_is_a_top_100_common_password'] = 'This is a top-100 common password';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.this_is_a_very_common_password'] = 'This is a very common password';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.this_is_similar_to_a_commonly_used_password'] = 'This is similar to a commonly used password';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.for_a_stronger_password_use_a_few_words_separated_by_spaces_but_avoid_common_phrases'] = 'For a stronger password, use a few words separated by spaces, but avoid common phrases';
  
    window.LoginGov.I18n.strings['en']['zxcvbn.feedback.use_a_longer_keyboard_pattern_with_more_turns'] = 'Use a longer keyboard pattern with more turns';
  
  window.LoginGov.I18n.strings['es'] = {};
  
    window.LoginGov.I18n.strings['es']['two_factor_authentication.otp_delivery_preference.instruction'] = 'Puede cambiar esta selección la próxima vez que inicie sesión.';
  
    window.LoginGov.I18n.strings['es']['two_factor_authentication.otp_delivery_preference.phone_unsupported'] = 'En este momento no podemos realizar llamadas a personas en %{location}.';
  
    window.LoginGov.I18n.strings['es']['errors.messages.format_mismatch'] = 'Por favor, use el formato solicitado.';
  
    window.LoginGov.I18n.strings['es']['errors.messages.missing_field'] = 'Por favor, rellene este campo.';
  
    window.LoginGov.I18n.strings['es']['forms.passwords.show'] = 'Mostrar contraseña';
  
    window.LoginGov.I18n.strings['es']['idv.errors.pattern_mismatch.dob'] = 'Su fecha de nacimiento debe ser ingresada en este formato mes/día/año.';
  
    window.LoginGov.I18n.strings['es']['idv.errors.pattern_mismatch.personal_key'] = 'Introduzca su clave personal para esta cuenta. Ejemplo: ABC1-DEF2-G3HI-J456';
  
    window.LoginGov.I18n.strings['es']['idv.errors.pattern_mismatch.ssn'] = 'Su número de Seguro Social debe ser ingresado como ### - ## - ####';
  
    window.LoginGov.I18n.strings['es']['idv.errors.pattern_mismatch.state_id_number'] = 'Su número de ID no puede tener más de 25 caracteres';
  
    window.LoginGov.I18n.strings['es']['idv.errors.pattern_mismatch.zipcode'] = 'Su código postal debe ser ingresado como #####-####';
  
    window.LoginGov.I18n.strings['es']['idv.failure.button.warning'] = 'Inténtelo de nuevo';
  
    window.LoginGov.I18n.strings['es']['instructions.password.strength.i'] = 'Muy débil';
  
    window.LoginGov.I18n.strings['es']['instructions.password.strength.ii'] = 'Débil';
  
    window.LoginGov.I18n.strings['es']['instructions.password.strength.iii'] = 'Más o menos';
  
    window.LoginGov.I18n.strings['es']['instructions.password.strength.iv'] = 'Buena';
  
    window.LoginGov.I18n.strings['es']['instructions.password.strength.v'] = '¡Muy buena!';
  
    window.LoginGov.I18n.strings['es']['simple_form.required.text'] = 'Este campo es requerido';
  
    window.LoginGov.I18n.strings['es']['valid_email.validations.email.invalid'] = 'El formato de email o dominio ingresado no es válido. Corrija su email y vuelva a intentarlo.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.a_word_by_itself_is_easy_to_guess'] = 'Una sola palabra es fácil de adivinar.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better'] = 'Añada otra palabra o dos. Las palabras poco comunes son mejor opción.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.all_uppercase_is_almost_as_easy_to_guess_as_all_lowercase'] = 'Todo en mayúsculas es casi igual de fácil de adivinar como todo en minúsculas.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.avoid_dates_and_years_that_are_associated_with_you'] = 'Evite las fechas y los años que están asociados con usted';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.avoid_recent_years'] = 'Evite los años recientes';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.avoid_repeated_words_and_characters'] = 'Evite palabras y caracteres repetidos';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.avoid_sequences'] = 'Evite secuencias';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.avoid_years_that_are_associated_with_you'] = 'Evite los años que están asociados con usted';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.capitalization_doesnt_help_very_much'] = 'Usar mayúsculas no ayuda mucho';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.common_names_and_surnames_are_easy_to_guess'] = 'Los nombres y apellidos comunes son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.dates_are_often_easy_to_guess'] = 'Las fechas suelen ser fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.names_and_surnames_by_themselves_are_easy_to_guess'] = 'Nombres y apellidos por si solos son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.there_is_no_need_for_symbols_digits_or_uppercase_letters'] = 'Las líneas seguidas de letras son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.predictable_substitutions_like__instead_of_a_dont_help_very_much'] = 'No hay necesidad de símbolos, dígitos o letras mayúsculas';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.recent_years_are_easy_to_guess'] = 'Sustituciones predecibles como \'@\' en lugar de \'a\' no ayudan mucho';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.repeats_like_aaa_are_easy_to_guess'] = 'Los años recientes son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.repeats_like_abcabcabc_are_only_slightly_harder_to_guess_than_abc'] = 'Las repeticiones como \"aaa\" son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.reversed_words_arent_much_harder_to_guess'] = 'Las repeticiones como \"abcabcabc\" son sólo un poco más difíciles de adivinar que \"abc\"';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.sequences_like_abc_or_6543_are_easy_to_guess'] = 'Las palabras invertidas no son mucho más difíciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.short_keyboard_patterns_are_easy_to_guess'] = 'Las secuencias como abc o 6543 son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.straight_rows_of_keys_are_easy_to_guess'] = 'Las combinaciones cortas de teclas son fáciles de adivinar';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.this_is_a_top_10_common_password'] = 'Esta es una de las 100 contraseñas más comunes.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.this_is_a_top_100_common_password'] = 'Esta es una de las 10 contraseñas más comunes.';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.this_is_a_very_common_password'] = 'Esta es una contraseña muy común';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.this_is_similar_to_a_commonly_used_password'] = 'Esto es similar a una contraseña comúnmente utilizada';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.for_a_stronger_password_use_a_few_words_separated_by_spaces_but_avoid_common_phrases'] = 'Para una contraseña más segura, use pocas palabras separadas por espacios, pero evite frases comunes';
  
    window.LoginGov.I18n.strings['es']['zxcvbn.feedback.use_a_longer_keyboard_pattern_with_more_turns'] = 'Use una combinación larga de teclas con más configuraciones';
  
  window.LoginGov.I18n.strings['fr'] = {};
  
    window.LoginGov.I18n.strings['fr']['two_factor_authentication.otp_delivery_preference.instruction'] = 'Vous pouvez changer cette sélection la prochaine fois que vous vous connectez.';
  
    window.LoginGov.I18n.strings['fr']['two_factor_authentication.otp_delivery_preference.phone_unsupported'] = 'Nous ne sommes pas en mesure de passer des appels téléphoniques aux personnes situées à %{location} pour le moment.';
  
    window.LoginGov.I18n.strings['fr']['errors.messages.format_mismatch'] = 'Veuillez vous assurer de respecter le format requis.';
  
    window.LoginGov.I18n.strings['fr']['errors.messages.missing_field'] = 'Veuillez remplir ce champ.';
  
    window.LoginGov.I18n.strings['fr']['forms.passwords.show'] = 'Afficher le mot de passe';
  
    window.LoginGov.I18n.strings['fr']['idv.errors.pattern_mismatch.dob'] = 'Votre date de naissance doit être inscrite de cette façon: mm/jj/aaaa';
  
    window.LoginGov.I18n.strings['fr']['idv.errors.pattern_mismatch.personal_key'] = 'Veuillez inscrire votre clé personnelle pour ce compte, par exemple : ABC1-DEF2-G3HI-J456';
  
    window.LoginGov.I18n.strings['fr']['idv.errors.pattern_mismatch.ssn'] = 'Votre numéro de sécurité sociale doit être inscrit de cette façon : ###-##-####';
  
    window.LoginGov.I18n.strings['fr']['idv.errors.pattern_mismatch.state_id_number'] = 'Votre numéro d\'identification ne peut excéder 25 caractères';
  
    window.LoginGov.I18n.strings['fr']['idv.errors.pattern_mismatch.zipcode'] = 'Votre code ZIP doit être inscrit de cette façon : #####-####';
  
    window.LoginGov.I18n.strings['fr']['idv.failure.button.warning'] = 'Essayez à nouveau';
  
    window.LoginGov.I18n.strings['fr']['instructions.password.strength.i'] = 'Très faible';
  
    window.LoginGov.I18n.strings['fr']['instructions.password.strength.ii'] = 'Faible';
  
    window.LoginGov.I18n.strings['fr']['instructions.password.strength.iii'] = 'Correct';
  
    window.LoginGov.I18n.strings['fr']['instructions.password.strength.iv'] = 'Bonne';
  
    window.LoginGov.I18n.strings['fr']['instructions.password.strength.v'] = 'Excellente!';
  
    window.LoginGov.I18n.strings['fr']['simple_form.required.text'] = 'Ce champ est requis';
  
    window.LoginGov.I18n.strings['fr']['valid_email.validations.email.invalid'] = 'Format d\'adresse courriel ou domaine entré non valide. Corrigez l\'adresse et entrez-la de nouveau.';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.a_word_by_itself_is_easy_to_guess'] = 'Un mot seul est facile à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better'] = 'Ajoutez un ou deux autres mots. Les mots non communs sont plus efficaces';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.all_uppercase_is_almost_as_easy_to_guess_as_all_lowercase'] = 'Tout en majuscules est presque aussi facile à deviner que tout en minuscules';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.avoid_dates_and_years_that_are_associated_with_you'] = 'Évitez les dates et années qui vous sont associées';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.avoid_recent_years'] = 'Évitez les années récentes';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.avoid_repeated_words_and_characters'] = 'Évitez les mots et caractères répétés';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.avoid_sequences'] = 'Évitez les séquences';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.avoid_years_that_are_associated_with_you'] = 'Évitez les années qui vous sont associées';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.capitalization_doesnt_help_very_much'] = 'La capitalisation n\'aide pas beaucoup';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.common_names_and_surnames_are_easy_to_guess'] = 'Les prénoms et noms de famille communs sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.dates_are_often_easy_to_guess'] = 'Les dates sont souvent faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.names_and_surnames_by_themselves_are_easy_to_guess'] = 'Les prénoms et noms de famille seuls sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.there_is_no_need_for_symbols_digits_or_uppercase_letters'] = 'Les symboles, les chiffres ou les lettres majuscules ne sont pas nécessaires';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.predictable_substitutions_like__instead_of_a_dont_help_very_much'] = 'Les remplacements prévisibles comme es « @ » au lieu de « à » n\'aident pas beaucoup';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.recent_years_are_easy_to_guess'] = 'Les années récentes sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.repeats_like_aaa_are_easy_to_guess'] = 'Les répétitions comme « aaa » sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.repeats_like_abcabcabc_are_only_slightly_harder_to_guess_than_abc'] = 'Les répétitions comme « abcabcabc » sont à peine\n         plus difficiles à deviner que « abc »';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.reversed_words_arent_much_harder_to_guess'] = 'Les mots inversés ne sont pas très difficiles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.sequences_like_abc_or_6543_are_easy_to_guess'] = 'Les séquences comme abc ou 6543 sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.short_keyboard_patterns_are_easy_to_guess'] = 'Les motifs de clavier courts sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.straight_rows_of_keys_are_easy_to_guess'] = 'Les rangées de lettres consécutives sont faciles à deviner';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.this_is_a_top_10_common_password'] = 'Il s\'agit d\'un des 10 mots de passe les plus communs';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.this_is_a_top_100_common_password'] = 'Il s\'agit d\'un des 100 mots de passe les plus communs';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.this_is_a_very_common_password'] = 'Il s\'agit d\'un mot de passe très commun';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.this_is_similar_to_a_commonly_used_password'] = 'Ceci est similaire à un mot de passe souvent utilisé';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.for_a_stronger_password_use_a_few_words_separated_by_spaces_but_avoid_common_phrases'] = 'Pour créer un mot de passe plus fort, utilisez quelques mots séparés par des espaces, mais évitez les phrases communes';
  
    window.LoginGov.I18n.strings['fr']['zxcvbn.feedback.use_a_longer_keyboard_pattern_with_more_turns'] = 'Utilisez un motif de clavier plus long avec plus de tours';
  
