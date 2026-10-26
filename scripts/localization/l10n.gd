class_name L10n
extends RefCounted


## Translate a stable message key; English wording lives in localization/*.csv.
## Unregistered custom text passes through. Format placeholders after translation.
static func text(key: String) -> String:
	return TranslationServer.translate(key)
