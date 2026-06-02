export const USER_BUBBLE_MAX_WIDTH: string = '75%'
export const ASSISTANT_BUBBLE_RADIUS: number = 16
export const ASSISTANT_BUBBLE_BORDER_WIDTH: number = 0.5
export const USER_BUBBLE_BORDER_WIDTH: number = 0.5

export function getAssistantBubblePadding(): Padding {
  return { left: 12, right: 12, top: 10, bottom: 10 }
}

export function getUserBubblePadding(hasAttachments: boolean): Padding {
  return hasAttachments ? { left: 8, right: 8, top: 8, bottom: 8 } : { left: 14, right: 14, top: 10, bottom: 10 }
}

export function getUserBubbleTextLineHeight(chatFontSize: number): number {
  return Math.round(chatFontSize * 1.4)
}

export function getUserBubbleRadius(): BorderRadiuses {
  return {
    topLeft: 20,
    topRight: 20,
    bottomLeft: 20,
    bottomRight: 6
  }
}
