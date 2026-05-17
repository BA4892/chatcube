import { motion } from '@kit.MultimodalAwarenessKit'

export const INDEX_NEW_CHAT_FAB_SIZE = 58
export const INDEX_NEW_CHAT_FAB_STACK_WIDTH = 58
export const INDEX_NEW_CHAT_FAB_STACK_HEIGHT = 58
export const INDEX_NEW_CHAT_FAB_BOTTOM_SPACING = 20

// 助手 tab 的"新建助手"使用 Extended FAB(胶囊 + 文字),与卡内圆形主按钮"新建对话"做视觉区分
export const INDEX_ASSISTANT_FAB_WIDTH = 132
export const INDEX_ASSISTANT_FAB_HEIGHT = 50

export function isHandAdaptiveActiveForIndex(enabled: boolean, newChatEnabled: boolean): boolean {
  if (!enabled) {
    return false
  }
  return newChatEnabled
}

export function shouldPlaceFabOnLeftForIndex(handAdaptiveEnabled: boolean, handAdaptiveNewChat: boolean,
  handAdaptiveUnsupported: boolean, currentHoldingHand: motion.HoldingHandStatus): boolean {
  if (!handAdaptiveEnabled || !handAdaptiveNewChat || handAdaptiveUnsupported) {
    return false
  }
  return currentHoldingHand === motion.HoldingHandStatus.LEFT_HAND_HELD
}

export function getFabOffsetXForIndex(placeOnLeft: boolean): number {
  if (placeOnLeft) {
    return 20
  }
  return -(INDEX_NEW_CHAT_FAB_SIZE + 20)
}

export function getAssistantFabOffsetXForIndex(placeOnLeft: boolean): number {
  if (placeOnLeft) {
    return 20
  }
  return -(INDEX_ASSISTANT_FAB_WIDTH + 20)
}

export function getFabOffsetYForIndex(bottomOverlayHeightVp: number): number {
  return -(INDEX_NEW_CHAT_FAB_STACK_HEIGHT + bottomOverlayHeightVp + INDEX_NEW_CHAT_FAB_BOTTOM_SPACING)
}

export function getAssistantFabOffsetYForIndex(bottomOverlayHeightVp: number): number {
  return -(INDEX_ASSISTANT_FAB_HEIGHT + bottomOverlayHeightVp + INDEX_NEW_CHAT_FAB_BOTTOM_SPACING)
}
