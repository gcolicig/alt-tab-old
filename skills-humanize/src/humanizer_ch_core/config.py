from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping

from .errors import ErrorCode, HumanizerError


SUPPORTED_LOCALES = {"de-CH", "de-DE", "de-AT", "en", "en-GB", "en-US", "fr-CH", "it-CH"}
SUPPORTED_LANGUAGES = {"und", "de", "en", "fr", "it"}
SUPPORTED_REGISTERS = {"locker", "sachlich", "formal"}
FOUNDATION_KEYS = {"language", "locale", "register", "routing_profile"}


@dataclass(frozen=True)
class EffectiveConfig:
    language: str
    locale: str | None
    register: str
    routing_profile: str
    provenance: dict[str, str]


def _first(name: str, layers: list[tuple[str, Mapping[str, object]]], default: object) -> tuple[object, str]:
    for origin, layer in layers:
        if name in layer and layer[name] is not None:
            return layer[name], origin
    return default, "builtin"


def resolve_config(
    invocation: Mapping[str, object] | None = None,
    project: Mapping[str, object] | None = None,
    user: Mapping[str, object] | None = None,
) -> EffectiveConfig:
    for origin, layer in (("invocation", invocation or {}), ("project", project or {}), ("user", user or {})):
        unknown = sorted(set(layer) - FOUNDATION_KEYS)
        if unknown:
            raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, f"Unbekannte Optionen in {origin}: {', '.join(unknown)}", "config", safe_action="fix_configuration")
    layers = [("invocation", invocation or {}), ("project", project or {}), ("user", user or {})]
    language, language_origin = _first("language", layers, "und")
    locale, locale_origin = _first("locale", layers, None)
    register, register_origin = _first("register", layers, "sachlich")
    routing, routing_origin = _first("routing_profile", layers, "practical_default@1")
    if not isinstance(language, str) or language not in SUPPORTED_LANGUAGES:
        raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, "Ungültige Sprache.", "config", safe_action="fix_configuration")
    if locale is not None and locale not in SUPPORTED_LOCALES:
        raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, f"Nicht unterstütztes Locale: {locale}", "config", safe_action="fix_configuration")
    locale_language = locale.split("-", 1)[0] if locale else None
    if locale_language and language == "und":
        language = locale_language
        language_origin = locale_origin
    elif locale_language and language != locale_language:
        raise HumanizerError(ErrorCode.CONFIG_LOCALE_CONFLICT, "Sprache und Locale widersprechen sich.", "config", safe_action="fix_configuration")
    if register not in SUPPORTED_REGISTERS:
        raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, f"Ungültiges Register: {register}", "config", safe_action="fix_configuration")
    if not isinstance(routing, str) or not routing:
        raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, "Ungültiges Routingprofil.", "config", safe_action="fix_configuration")
    return EffectiveConfig(
        language=language,
        locale=locale,
        register=register,
        routing_profile=routing,
        provenance={
            "language": language_origin,
            "locale": locale_origin,
            "register": register_origin,
            "routing_profile": routing_origin,
        },
    )
