export enum LayoutSizeClass {
  COMPACT = 'compact',
  MEDIUM = 'medium',
  EXPANDED = 'expanded'
}

const COMPACT_MAX_WIDTH_VP = 600
const EXPANDED_MIN_WIDTH_VP = 840
export const INDEX_EXPANDED_NAV_RAIL_WIDTH: number = 88
export const CHAT_SPLIT_LIST_PANE_MIN_WIDTH: number = 240
export const CHAT_SPLIT_LIST_PANE_DEFAULT_MIN_WIDTH: number = 300
export const CHAT_SPLIT_LIST_PANE_MAX_WIDTH: number = 520
export const CHAT_SPLIT_DETAIL_PANE_MIN_WIDTH: number = 360
const CHAT_SPLIT_DEFAULT_LIST_RATIO = 0.32

export function resolveLayoutSizeClass(widthVp: number): LayoutSizeClass {
  if (widthVp < COMPACT_MAX_WIDTH_VP) {
    return LayoutSizeClass.COMPACT
  }
  if (widthVp < EXPANDED_MIN_WIDTH_VP) {
    return LayoutSizeClass.MEDIUM
  }
  return LayoutSizeClass.EXPANDED
}

export function isExpandedLayoutClass(sizeClass: string): boolean {
  return sizeClass === LayoutSizeClass.EXPANDED
}

export function getIndexChatListPaneWidth(widthVp: number): number {
  if (widthVp >= 1360) {
    return 420
  }
  if (widthVp >= 1120) {
    return 380
  }
  return 340
}

export function getIndexChatNavigationAvailableWidth(widthVp: number, layoutSizeClass: string): number {
  if (widthVp <= 0) {
    return 0
  }
  if (layoutSizeClass !== LayoutSizeClass.EXPANDED) {
    return widthVp
  }
  const horizontalPadding = getIndexPageHorizontalPadding(widthVp) * 2
  return Math.max(0, widthVp - INDEX_EXPANDED_NAV_RAIL_WIDTH - horizontalPadding)
}

export function getMaxIndexChatListPaneWidth(availableWidthVp: number): number {
  if (availableWidthVp <= 0) {
    return CHAT_SPLIT_LIST_PANE_MIN_WIDTH
  }
  const contentLimitedMax = availableWidthVp - CHAT_SPLIT_DETAIL_PANE_MIN_WIDTH
  const maxWidth = Math.min(CHAT_SPLIT_LIST_PANE_MAX_WIDTH, contentLimitedMax)
  return Math.max(CHAT_SPLIT_LIST_PANE_MIN_WIDTH, maxWidth)
}

export function clampIndexChatListPaneWidth(widthVp: number, availableWidthVp: number): number {
  if (widthVp <= 0) {
    return CHAT_SPLIT_LIST_PANE_MIN_WIDTH
  }
  const maxWidth = getMaxIndexChatListPaneWidth(availableWidthVp)
  if (widthVp < CHAT_SPLIT_LIST_PANE_MIN_WIDTH) {
    return CHAT_SPLIT_LIST_PANE_MIN_WIDTH
  }
  if (widthVp > maxWidth) {
    return maxWidth
  }
  return Math.round(widthVp)
}

export function getDefaultIndexChatListPaneWidth(availableWidthVp: number): number {
  if (availableWidthVp <= 0) {
    return CHAT_SPLIT_LIST_PANE_DEFAULT_MIN_WIDTH
  }
  return clampIndexChatListPaneWidth(
    Math.max(CHAT_SPLIT_LIST_PANE_DEFAULT_MIN_WIDTH, Math.round(availableWidthVp * CHAT_SPLIT_DEFAULT_LIST_RATIO)),
    availableWidthVp
  )
}

export function shouldUseIndexChatSplitLayout(
  widthVp: number,
  heightVp: number,
  layoutSizeClass: string
): boolean {
  if (layoutSizeClass === LayoutSizeClass.COMPACT) {
    return false
  }
  if (widthVp <= 0 || heightVp <= 0 || widthVp <= heightVp) {
    return false
  }
  const availableWidth = getIndexChatNavigationAvailableWidth(widthVp, layoutSizeClass)
  return availableWidth >= CHAT_SPLIT_LIST_PANE_MIN_WIDTH + CHAT_SPLIT_DETAIL_PANE_MIN_WIDTH
}

export function getIndexPageHorizontalPadding(widthVp: number): number {
  if (widthVp >= 1360) {
    return 20
  }
  if (widthVp >= 1120) {
    return 16
  }
  return 12
}

export function getChatContentMaxWidth(widthVp: number): number {
  if (widthVp >= 1360) {
    return 1040
  }
  if (widthVp >= 1120) {
    return 960
  }
  return 900
}

export function getCenteredPageMaxWidth(widthVp: number): number {
  if (widthVp >= 1360) {
    return 980
  }
  if (widthVp >= 1120) {
    return 900
  }
  return 760
}
