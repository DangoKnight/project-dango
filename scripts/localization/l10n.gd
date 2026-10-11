class_name L10n
extends RefCounted


## Translate presentation text without changing resource IDs or source strings.
## The source English text is the key. Format placeholders after translation.
static func text(source: String) -> String:
	return TranslationServer.translate(source)
