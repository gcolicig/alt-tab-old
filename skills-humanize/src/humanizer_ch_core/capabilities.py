from __future__ import annotations

from dataclasses import dataclass
import importlib.util
from pathlib import Path


@dataclass(frozen=True)
class Capability:
    capability_id: str
    provider_id: str
    configured: bool
    enabled: bool
    required: bool
    availability: str
    probe_method: str
    probe_revision: str = "1"
    reason_code: str = "NOT_CONFIGURED"

    def as_dict(self) -> dict[str, object]:
        return self.__dict__.copy()


def module_capability(capability_id: str, module: str, enabled: bool = False, required: bool = False) -> Capability:
    available = importlib.util.find_spec(module) is not None
    return Capability(
        capability_id=capability_id,
        provider_id=module,
        configured=available,
        enabled=enabled and available,
        required=required,
        availability="available" if available else "unavailable",
        probe_method="metadata",
        reason_code="AVAILABLE" if available else "MODULE_NOT_FOUND",
    )


def artifact_capability(capability_id: str, provider_id: str, artifact: Path | None, enabled: bool = False, required: bool = False) -> Capability:
    configured = artifact is not None
    available = bool(artifact and artifact.exists())
    return Capability(
        capability_id=capability_id,
        provider_id=provider_id,
        configured=configured,
        enabled=enabled and available,
        required=required,
        availability="available" if available else "unavailable" if configured else "unknown",
        probe_method="artifact_manifest" if configured else "not_run",
        reason_code="AVAILABLE" if available else "ARTIFACT_NOT_FOUND" if configured else "NOT_CONFIGURED",
    )


def foundation_capabilities() -> list[Capability]:
    return [
        module_capability("yaml_validation", "yaml"),
        module_capability("grammar_spacy", "spacy"),
        artifact_capability("translation_gemma_27b", "translategemma-27b", None),
    ]
