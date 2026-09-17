from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from uuid import uuid4


class ErrorCode(str, Enum):
    INPUT_EMPTY = "HC_INPUT_EMPTY"
    INPUT_SCOPE_INVALID = "HC_INPUT_SCOPE_INVALID"
    INPUT_REVISION_MISMATCH = "HC_INPUT_REVISION_MISMATCH"
    CONFIG_PROFILE_INVALID = "HC_CONFIG_PROFILE_INVALID"
    CONFIG_LOCALE_CONFLICT = "HC_CONFIG_LOCALE_CONFLICT"
    ADAPTER_UNAVAILABLE = "HC_ADAPTER_UNAVAILABLE"
    INVARIANT_FAILED = "HC_INVARIANT_STRUCTURE"
    IO_READ = "HC_IO_READ"
    CHECK_REQUIRED_NOT_RUN = "HC_CHECK_REQUIRED_NOT_RUN"
    INTERNAL = "HC_INTERNAL_UNEXPECTED"


EXIT_CODES = {
    ErrorCode.INPUT_EMPTY: 2,
    ErrorCode.INPUT_SCOPE_INVALID: 2,
    ErrorCode.INPUT_REVISION_MISMATCH: 2,
    ErrorCode.CONFIG_PROFILE_INVALID: 3,
    ErrorCode.CONFIG_LOCALE_CONFLICT: 3,
    ErrorCode.ADAPTER_UNAVAILABLE: 6,
    ErrorCode.INVARIANT_FAILED: 5,
    ErrorCode.IO_READ: 9,
    ErrorCode.CHECK_REQUIRED_NOT_RUN: 12,
    ErrorCode.INTERNAL: 10,
}


CATEGORIES = {
    ErrorCode.INPUT_EMPTY: "input",
    ErrorCode.INPUT_SCOPE_INVALID: "input",
    ErrorCode.INPUT_REVISION_MISMATCH: "input",
    ErrorCode.CONFIG_PROFILE_INVALID: "configuration",
    ErrorCode.CONFIG_LOCALE_CONFLICT: "configuration",
    ErrorCode.ADAPTER_UNAVAILABLE: "adapter",
    ErrorCode.INVARIANT_FAILED: "invariant",
    ErrorCode.IO_READ: "io",
    ErrorCode.CHECK_REQUIRED_NOT_RUN: "check",
    ErrorCode.INTERNAL: "internal",
}


DEFAULT_RETRYABILITY = {
    "input": "after_input_change",
    "configuration": "after_config_change",
    "adapter": "after_config_change",
    "invariant": "after_input_change",
    "io": "after_user_action",
    "check": "after_config_change",
    "internal": "unknown",
}


DEFAULT_SAFE_ACTION = {
    "input": "fix_input",
    "configuration": "fix_configuration",
    "adapter": "choose_adapter",
    "invariant": "inspect_report",
    "io": "choose_output",
    "check": "inspect_report",
    "internal": "report_defect",
}


@dataclass(frozen=True)
class HumanizerError(Exception):
    code: ErrorCode
    message: str
    component: str
    retryability: str | None = None
    safe_action: str | None = None
    correlation_id: str = field(default_factory=lambda: f"run-{uuid4().hex}")

    def as_dict(self) -> dict[str, object]:
        category = CATEGORIES[self.code]
        return {
            "code": self.code.value,
            "category": category,
            "component": self.component,
            "severity": "error",
            "retryability": self.retryability or DEFAULT_RETRYABILITY[category],
            "safe_action": self.safe_action or DEFAULT_SAFE_ACTION[category],
            "message_key": self.code.value.lower().replace("hc_", "humanizer_ch.").replace("_", "."),
            "correlation_id": self.correlation_id,
        }

    @property
    def exit_code(self) -> int:
        return EXIT_CODES[self.code]
