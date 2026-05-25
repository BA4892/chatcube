import { ChatMessage } from '../../models/ChatModels'

export interface ChatScrollUiFlowDependencies {
  scroller: Scroller
  messages: ChatMessage[]
  getBottomAnchorIndex: () => number
  getCurrentScrollOffset: () => number
  syncCurrentScrollOffset: () => number
  syncIsAtBottomBoundary: () => boolean
  getLastScrollOffset: () => number
  setLastScrollOffset: (value: number) => void
  getMaxScrollOffset: () => number
  setMaxScrollOffset: (value: number) => void
  getFirstVisibleIndex: () => number
  getLastVisibleIndex: () => number
  getTotalListItemCount: () => number
  getInputBarShowThreshold: () => number
  getInputBarHideThreshold: () => number
  getIsAtTop: () => boolean
  getIsAtBottom: () => boolean
  getIsInputBarVisible: () => boolean
  getIsSending: () => boolean
  getIsEditingMessage: () => boolean
  getEditingMessageId: () => string
  hasDraftContent: () => boolean
  onSetIsAtTopState: (value: boolean) => void
  onSetIsAtBottomState: (value: boolean) => void
  onSetInputBarVisibleState: (value: boolean) => void
  onSetCurrentScrollOffsetState: (value: number) => void
  onAnimate: (duration: number, curve: Curve, updater: () => void) => void
}

export class ChatScrollUiFlow {
  private static readonly BOTTOM_OFFSET_TOLERANCE_VP: number = 8
  private static readonly BOTTOM_AWAY_DELTA_VP: number = 10
  private static readonly PAGE_SCROLL_BOTTOM_PIN_MUTE_MS: number = 700
  private static readonly EDGE_SCROLL_BOTTOM_PIN_MUTE_MS: number = 1400
  private static readonly TOP_ANCHOR_INDEX: number = 0
  private static readonly EDGE_SCROLL_TARGET_NONE: number = 0
  private static readonly EDGE_SCROLL_TARGET_TOP: number = 1
  private static readonly EDGE_SCROLL_TARGET_BOTTOM: number = 2
  private deps: ChatScrollUiFlowDependencies
  private pinnedBottomAlignmentTimerIds: number[] = []
  private pinnedBottomAlignmentCompletionTimerId: number = -1
  private pendingPinnedBottomAlignment: boolean = false
  private bottomPinMutedUntil: number = 0
  private bottomLayoutPinActive: boolean = false
  private pendingEdgeScrollTarget: number = ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE
  private pendingEdgeScrollCorrectionIssued: boolean = false

  constructor(deps: ChatScrollUiFlowDependencies) {
    this.deps = deps
  }

  private normalizeScrollOffset(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return 0
    }
    return value
  }

  private setCurrentScrollOffset(value: number): void {
    this.deps.onSetCurrentScrollOffsetState(this.normalizeScrollOffset(value))
  }

  private isWithinBottomTolerance(offset: number): boolean {
    const maxScrollOffset = this.deps.getMaxScrollOffset()
    if (maxScrollOffset <= 0) {
      return false
    }
    return maxScrollOffset - offset <= ChatScrollUiFlow.BOTTOM_OFFSET_TOLERANCE_VP
  }

  private resolveStableBottomOffset(offset: number): number {
    const maxScrollOffset = this.deps.getMaxScrollOffset()
    if (maxScrollOffset <= 0) {
      return offset
    }
    return Math.max(offset, maxScrollOffset)
  }

  private hasPassedInputBarHideRange(): boolean {
    const totalItems = this.deps.getTotalListItemCount()
    if (totalItems <= 1) {
      return false
    }
    const firstVisible = this.deps.getFirstVisibleIndex()
    const lastVisible = this.deps.getLastVisibleIndex()
    const scrollableItems = totalItems - (lastVisible - firstVisible + 1)
    if (scrollableItems <= 0) {
      return false
    }
    return firstVisible / scrollableItems > 0.2
  }

  private captureBottomScrollBaseline(): void {
    const currentOffset = this.normalizeScrollOffset(this.deps.syncCurrentScrollOffset())
    this.setCurrentScrollOffset(currentOffset)
    this.deps.setLastScrollOffset(currentOffset)
    if (currentOffset > this.deps.getMaxScrollOffset()) {
      this.deps.setMaxScrollOffset(currentOffset)
    }
  }

  private clearPinnedBottomAlignmentTimers(): void {
    for (let i = 0; i < this.pinnedBottomAlignmentTimerIds.length; i++) {
      clearTimeout(this.pinnedBottomAlignmentTimerIds[i])
    }
    this.pinnedBottomAlignmentTimerIds = []
    if (this.pinnedBottomAlignmentCompletionTimerId >= 0) {
      clearTimeout(this.pinnedBottomAlignmentCompletionTimerId)
      this.pinnedBottomAlignmentCompletionTimerId = -1
    }
    this.pendingPinnedBottomAlignment = false
  }

  private isBottomPinMuted(): boolean {
    return Date.now() < this.bottomPinMutedUntil
  }

  private muteBottomPin(durationMs: number): void {
    this.bottomPinMutedUntil = Math.max(this.bottomPinMutedUntil, Date.now() + durationMs)
    this.clearBottomLayoutPin()
    this.clearPinnedBottomAlignmentTimers()
  }

  private clearBottomPinMute(): void {
    this.bottomPinMutedUntil = 0
  }

  private activateBottomLayoutPin(): void {
    if (this.isBottomPinMuted()) {
      return
    }
    this.bottomLayoutPinActive = true
  }

  private clearBottomLayoutPin(): void {
    this.bottomLayoutPinActive = false
  }

  private syncBottomScrollBaselineAfterLayout(): void {
    setTimeout(() => {
      this.captureBottomScrollBaseline()
    }, 0)
    setTimeout(() => {
      this.captureBottomScrollBaseline()
    }, 50)
  }

  private scrollBottomAnchor(smooth: boolean): void {
    const bottomAnchorIndex = this.deps.getBottomAnchorIndex()
    if (bottomAnchorIndex >= 0) {
      this.deps.scroller.scrollToIndex(bottomAnchorIndex, smooth, ScrollAlign.END)
      return
    }
    this.deps.scroller.scrollEdge(Edge.Bottom)
  }

  private scrollTopAnchor(smooth: boolean): void {
    try {
      this.deps.scroller.scrollToIndex(ChatScrollUiFlow.TOP_ANCHOR_INDEX, smooth, ScrollAlign.START)
    } catch (_error) {
      this.deps.scroller.scrollEdge(Edge.Top)
    }
  }

  private setPendingEdgeScrollTarget(target: number): void {
    this.pendingEdgeScrollTarget = target
    this.pendingEdgeScrollCorrectionIssued = false
  }

  private clearPendingEdgeScrollTarget(): void {
    this.pendingEdgeScrollTarget = ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE
    this.pendingEdgeScrollCorrectionIssued = false
  }

  private clearPendingBottomScrollTarget(): void {
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      this.clearPendingEdgeScrollTarget()
    }
  }

  private isAtTopBoundary(): boolean {
    return this.deps.getIsAtTop() || this.normalizeScrollOffset(this.deps.syncCurrentScrollOffset()) <= 0
  }

  private isAtBottomBoundary(): boolean {
    const bottomAnchorIndex = this.deps.getBottomAnchorIndex()
    return this.deps.syncIsAtBottomBoundary() ||
      (bottomAnchorIndex >= 0 && this.deps.getLastVisibleIndex() >= bottomAnchorIndex)
  }

  private verifyPendingTopScrollOnStop(): boolean {
    if (this.isAtTopBoundary()) {
      this.clearPendingEdgeScrollTarget()
      return true
    }
    if (this.pendingEdgeScrollCorrectionIssued) {
      this.clearPendingEdgeScrollTarget()
      return true
    }
    this.pendingEdgeScrollCorrectionIssued = true
    this.scrollTopAnchor(false)
    return true
  }

  private verifyPendingBottomScrollOnStop(): boolean {
    if (this.isAtBottomBoundary()) {
      this.activateBottomLayoutPin()
      this.captureBottomScrollBaseline()
      this.clearPendingEdgeScrollTarget()
      return true
    }
    if (this.pendingEdgeScrollCorrectionIssued) {
      this.clearPendingEdgeScrollTarget()
      return true
    }
    this.pendingEdgeScrollCorrectionIssued = true
    this.scrollBottomAnchor(false)
    this.captureBottomScrollBaseline()
    return true
  }

  alignToBottomAfterLayout(): void {
    this.activateBottomLayoutPin()
    setTimeout(() => {
      this.scrollBottomAnchor(false)
    }, 0)
    setTimeout(() => {
      this.scrollBottomAnchor(false)
    }, 50)
    this.syncBottomScrollBaselineAfterLayout()
  }

  private schedulePinnedBottomAlignmentAfterLayout(): void {
    if (this.isBottomPinMuted()) {
      return
    }
    if (this.pendingPinnedBottomAlignment) {
      return
    }
    this.pendingPinnedBottomAlignment = true
    const delays: number[] = [0, 50]
    for (let i = 0; i < delays.length; i++) {
      const timerId = setTimeout(() => {
        if (!this.pendingPinnedBottomAlignment || !this.deps.getIsAtBottom()) {
          this.clearPinnedBottomAlignmentTimers()
          return
        }
        this.scrollBottomAnchor(false)
        this.captureBottomScrollBaseline()
      }, delays[i])
      this.pinnedBottomAlignmentTimerIds.push(timerId)
    }
    this.pinnedBottomAlignmentCompletionTimerId = setTimeout(() => {
      this.clearPinnedBottomAlignmentTimers()
    }, 120)
  }

  alignToBottomIfPinned(): void {
    if (this.isBottomPinMuted()) {
      return
    }
    if (!this.deps.getIsAtBottom()) {
      return
    }
    this.schedulePinnedBottomAlignmentAfterLayout()
  }

  setIsAtTop(value: boolean): void {
    if (this.deps.getIsAtTop() === value) {
      return
    }
    this.deps.onSetIsAtTopState(value)
  }

  setIsAtBottom(value: boolean): void {
    if (this.deps.getIsAtBottom() === value) {
      return
    }
    this.deps.onSetIsAtBottomState(value)
  }

  setInputBarVisible(value: boolean): void {
    if (this.deps.getIsInputBarVisible() === value) {
      return
    }
    this.deps.onSetInputBarVisibleState(value)
  }

  handleMessageListDidScroll(scrollOffset: number, scrollState: ScrollState): boolean {
    const lastScrollOffset = this.deps.getLastScrollOffset()
    const measuredOffset = this.normalizeScrollOffset(this.deps.syncCurrentScrollOffset())
    const reportedOffset = this.normalizeScrollOffset(scrollOffset)
    const cumulativeOffset = measuredOffset > 0 ? measuredOffset : reportedOffset
    const isActiveScroll = scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling
    const isMovingAwayFromBottom = isActiveScroll &&
      cumulativeOffset < lastScrollOffset - ChatScrollUiFlow.BOTTOM_AWAY_DELTA_VP
    const keepPinnedToBottom = !this.isBottomPinMuted() && !isMovingAwayFromBottom &&
      (this.deps.syncIsAtBottomBoundary() ||
      (this.deps.getIsAtBottom() && this.isWithinBottomTolerance(cumulativeOffset))
      )
    const effectiveOffset = keepPinnedToBottom ? this.resolveStableBottomOffset(cumulativeOffset) : cumulativeOffset

    this.setCurrentScrollOffset(effectiveOffset)
    const positionDelta = effectiveOffset - lastScrollOffset
    const userScrolledAwayFromBottom = !keepPinnedToBottom &&
      (isMovingAwayFromBottom || (positionDelta < 0 &&
      (scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling)))

    if (userScrolledAwayFromBottom) {
      this.clearPinnedBottomAlignmentTimers()
      this.clearPendingBottomScrollTarget()
      this.clearBottomLayoutPin()
    }

    if (keepPinnedToBottom) {
      this.activateBottomLayoutPin()
      this.setIsAtBottom(true)
      this.setInputBarVisible(true)
    } else if (userScrolledAwayFromBottom && this.deps.getIsAtBottom()) {
      this.setIsAtBottom(false)
    }

    if (scrollState === ScrollState.Scroll && effectiveOffset > 0) {
      this.setIsAtTop(false)
    }

    if (scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling) {
      if (positionDelta > this.deps.getInputBarShowThreshold()) {
        this.setInputBarVisible(true)
      } else if (positionDelta < -this.deps.getInputBarHideThreshold()) {
        if (!this.deps.getIsAtBottom() &&
          !this.deps.getIsSending() &&
          !this.deps.getIsEditingMessage() &&
          this.hasPassedInputBarHideRange()) {
          this.setInputBarVisible(false)
        }
      }

      this.deps.setLastScrollOffset(effectiveOffset)
    }

    return userScrolledAwayFromBottom
  }

  onDraftContentChanged(): void {
    if (!this.deps.getIsEditingMessage() && this.deps.getEditingMessageId() === '' &&
      this.deps.hasDraftContent()) {
      this.alignToBottomAfterLayout()
    }
  }

  scrollToBottomWithAnimation(): void {
    this.clearPinnedBottomAlignmentTimers()
    this.clearBottomPinMute()
    this.activateBottomLayoutPin()
    this.setPendingEdgeScrollTarget(ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM)
    this.setIsAtBottom(true)
    this.setIsAtTop(false)
    this.setInputBarVisible(true)
    this.scrollBottomAnchor(true)
    this.captureBottomScrollBaseline()
  }

  scrollToTopWithAnimation(): void {
    this.muteBottomPin(ChatScrollUiFlow.EDGE_SCROLL_BOTTOM_PIN_MUTE_MS)
    this.setPendingEdgeScrollTarget(ChatScrollUiFlow.EDGE_SCROLL_TARGET_TOP)
    this.setIsAtBottom(false)
    this.setInputBarVisible(true)
    this.scrollTopAnchor(true)
  }

  handleScrollStart(): void {
    if (this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE) {
      return
    }
    this.clearPinnedBottomAlignmentTimers()
    this.clearBottomLayoutPin()
  }

  handleScrollStop(): boolean {
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_TOP) {
      return this.verifyPendingTopScrollOnStop()
    }
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      return this.verifyPendingBottomScrollOnStop()
    }
    if (!this.isBottomPinMuted() && this.isAtBottomBoundary()) {
      this.activateBottomLayoutPin()
      this.setIsAtBottom(true)
      this.setInputBarVisible(true)
      this.captureBottomScrollBaseline()
    }
    return false
  }

  handleContentLayoutChanged(): void {
    if (this.isBottomPinMuted()) {
      return
    }
    if (this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM &&
      !this.bottomLayoutPinActive &&
      !this.deps.syncIsAtBottomBoundary()) {
      return
    }
    this.activateBottomLayoutPin()
    this.clearPinnedBottomAlignmentTimers()
    this.setIsAtBottom(true)
    this.setInputBarVisible(true)
    this.scrollBottomAnchor(false)
    this.captureBottomScrollBaseline()
  }

  scrollPageUpWithAnimation(): void {
    this.muteBottomPin(ChatScrollUiFlow.PAGE_SCROLL_BOTTOM_PIN_MUTE_MS)
    this.clearPendingBottomScrollTarget()
    this.setIsAtBottom(false)
    this.setInputBarVisible(true)
    this.deps.scroller.scrollPage({ next: false })
  }

  scrollPageDownWithAnimation(): void {
    this.clearPinnedBottomAlignmentTimers()
    this.setIsAtTop(false)
    this.setInputBarVisible(true)
    this.deps.scroller.scrollPage({ next: true })
  }

  handleReachStart(): void {
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_TOP) {
      this.clearPendingEdgeScrollTarget()
    }
    this.clearBottomLayoutPin()
    this.setCurrentScrollOffset(0)
    this.deps.setLastScrollOffset(0)
    this.setIsAtTop(true)
  }

  handleReachEnd(): void {
    if (this.isBottomPinMuted()) {
      return
    }
    const cumulativeOffset = this.deps.syncCurrentScrollOffset()
    this.deps.setLastScrollOffset(cumulativeOffset)
    this.activateBottomLayoutPin()
    this.setIsAtBottom(true)
    this.setInputBarVisible(true)
    this.captureBottomScrollBaseline()
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      this.pendingEdgeScrollCorrectionIssued = false
    }
  }
}
