export const HOLDING_HAND_STATUS_LEFT = 1
export const HOLDING_HAND_STATUS_RIGHT = 2
export const HOLDING_HAND_STATUS_UNKNOWN = 16

export function isExplicitHoldingHandStatus(status: number): boolean {
  return status === HOLDING_HAND_STATUS_LEFT || status === HOLDING_HAND_STATUS_RIGHT
}

export function shouldUseLeftHandAdaptiveLayout(enabled: boolean, unsupported: boolean, status: number): boolean {
  return enabled && !unsupported && status === HOLDING_HAND_STATUS_LEFT
}
