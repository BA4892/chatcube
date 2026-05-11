import { ReasoningLevel } from '../../models/ChatModels'
import { ReasoningControlMode } from '../../services/registry/CompatibilityResolver'

export function normalizeStoredChatReasoningLevel(value: string): ReasoningLevel {
  switch (value) {
    case ReasoningLevel.OFF:
      return ReasoningLevel.OFF
    case ReasoningLevel.AUTO:
      return ReasoningLevel.AUTO
    case ReasoningLevel.LOW:
      return ReasoningLevel.LOW
    case ReasoningLevel.MEDIUM:
      return ReasoningLevel.MEDIUM
    case ReasoningLevel.HIGH:
      return ReasoningLevel.HIGH
    case ReasoningLevel.XHIGH:
      return ReasoningLevel.XHIGH
    default:
      return ReasoningLevel.OFF
  }
}

export function resolveModelSwitchReasoningLevel(_controlMode: ReasoningControlMode): ReasoningLevel {
  return ReasoningLevel.OFF
}
