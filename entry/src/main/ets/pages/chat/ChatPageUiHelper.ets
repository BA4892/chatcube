export function shouldShowToolSelectionChipForChat(availableToolCount: number, selectedToolCount: number): boolean {
  return availableToolCount > 0 || selectedToolCount > 0
}

export function getListBottomPaddingForChat(pendingAttachmentCount: number, isEditingMessage: boolean,
  bottomAvoidHeightVp: number): number {
  let base = 90
  if (pendingAttachmentCount > 0) {
    base += 80
  }
  if (isEditingMessage) {
    base += 80
  }
  return base + bottomAvoidHeightVp
}

export function getPreviewTimeTextForChat(date: Date): string {
  const hours = date.getHours()
  const minutes = date.getMinutes()
  const ampm = hours >= 12 ? 'PM' : 'AM'
  const h = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours)
  const m = minutes < 10 ? '0' + minutes.toString() : minutes.toString()
  return h.toString() + ':' + m + ' ' + ampm
}
