"""Deterministic core for the Humanizer CH plugin."""

from .config import EffectiveConfig, resolve_config
from .scope import Document, Selection, create_document, select_span

__all__ = ["Document", "EffectiveConfig", "Selection", "create_document", "resolve_config", "select_span"]
__version__ = "0.1.0"
