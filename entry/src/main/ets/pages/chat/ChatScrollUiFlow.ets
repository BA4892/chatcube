import { ChatMessage } from '../../models/ChatModels'
import { LengthMetrics } from '@kit.ArkUI'

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
  private static readonly EDGE_SCROLL_CORRECTION_MAX_COUNT: number = 6
  private static readonly EDGE_SCROLL_CORRECTION_WINDOW_MS: number = 2000
  private static readonly BOTTOM_EDGE_PRELOAD_ITEM_COUNT: number = 3
  private static readonly BOTTOM_EDGE_PRELOAD_SETTLE_MS: number = 50
  private static readonly BOTTOM_EDGE_ANIMATION_DURATION_MS: number = 320
  // 流式跟随到底的动画时长. 比 BOTTOM_EDGE_ANIMATION_DURATION_MS 短, 因为这条路径在每个 chunk 都可能触发,
  // 单次动画太长容易堆叠抖动; 200ms 与 ChatGPT 网页端的滚动跟随节奏相近
  private static readonly PIN_BOTTOM_ALIGNMENT_ANIMATION_DURATION_MS: number = 200
  private static readonly INDEXED_SCROLL_TARGET_NONE: number = -1
  private static readonly INDEXED_SCROLL_PHASE_NONE: number = 0
  private static readonly INDEXED_SCROLL_PHASE_WAIT_APPEAR: number = 1
  private static readonly INDEXED_SCROLL_PHASE_WAIT_STABLE: number = 2
  private static readonly INDEXED_SCROLL_PHASE_FINE_TUNE: number = 3
  private static readonly INDEXED_SCROLL_CORRECTION_MAX_COUNT: number = 8
  private static readonly INDEXED_SCROLL_FINE_TUNE_WINDOW_MS: number = 800
  private static readonly INDEXED_SCROLL_WAIT_STABLE_TIMEOUT_MS: number = 1500
  private static readonly INDEXED_SCROLL_UNMEASURED_FALLBACK_MS: number = 80
  private static readonly INDEXED_SCROLL_STABLE_HEIGHT_DELTA_VP: number = 2
  private static readonly INDEXED_SCROLL_STABLE_TICK_TARGET: number = 2
  private deps: ChatScrollUiFlowDependencies
  private pinnedBottomAlignmentTimerIds: number[] = []
  private pinnedBottomAlignmentCompletionTimerId: number = -1
  private pendingPinnedBottomAlignment: boolean = false
  private bottomPinMutedUntil: number = 0
  private bottomLayoutPinActive: boolean = false
  private pendingEdgeScrollTarget: number = ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE
  private pendingEdgeScrollCorrectionCount: number = 0
  private pendingEdgeScrollCorrectionDeadline: number = 0
  private pendingBottomEdgePreloadActive: boolean = false
  private pendingIndexedScrollTarget: number = ChatScrollUiFlow.INDEXED_SCROLL_TARGET_NONE
  private pendingIndexedScrollAlign: ScrollAlign = ScrollAlign.CENTER
  private pendingIndexedScrollOffset: number = 0
  private pendingIndexedScrollCorrectionCount: number = 0
  private pendingIndexedScrollCorrectionDeadline: number = 0
  private pendingIndexedScrollPhase: number = ChatScrollUiFlow.INDEXED_SCROLL_PHASE_NONE
  private pendingIndexedTargetLastHeight: number = 0
  private pendingIndexedTargetStableTickCount: number = 0
  private pendingIndexedScrollPhaseTimerId: number = -1
  private interactiveContentResizePending: boolean = false

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

  private clearInteractiveContentResizePending(): void {
    this.interactiveContentResizePending = false
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

  private clearBottomFollowState(updateBottomState: boolean = true): void {
    this.clearPinnedBottomAlignmentTimers()
    this.clearPendingBottomScrollTarget()
    this.clearBottomLayoutPin()
    if (updateBottomState && this.deps.getIsAtBottom()) {
      this.setIsAtBottom(false)
    }
  }

  public shouldKeepBottomPinned(): boolean {
    if (this.isBottomPinMuted() || !this.deps.getIsAtBottom()) {
      return false
    }
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM ||
      this.bottomLayoutPinActive) {
      return true
    }
    return this.deps.syncIsAtBottomBoundary()
  }

  private syncBottomScrollBaselineAfterLayout(): void {
    setTimeout(() => {
      this.captureBottomScrollBaseline()
    }, 0)
    setTimeout(() => {
      this.captureBottomScrollBaseline()
    }, 50)
  }

  private scrollBottomEdge(): void {
    try {
      this.deps.scroller.scrollEdge(Edge.Bottom)
    } catch (_error) {
      const bottomAnchorIndex = this.deps.getBottomAnchorIndex()
      if (bottomAnchorIndex >= 0) {
        this.deps.scroller.scrollToIndex(bottomAnchorIndex, false, ScrollAlign.END)
      }
    }
  }

  private scrollTopEdge(): void {
    try {
      this.deps.scroller.scrollEdge(Edge.Top)
    } catch (_error) {
      this.deps.scroller.scrollToIndex(ChatScrollUiFlow.TOP_ANCHOR_INDEX, false, ScrollAlign.START)
    }
  }

  private scrollNearBottomEdgeForPreload(): boolean {
    const bottomAnchorIndex = this.deps.getBottomAnchorIndex()
    if (bottomAnchorIndex <= ChatScrollUiFlow.BOTTOM_EDGE_PRELOAD_ITEM_COUNT) {
      return false
    }
    const preloadIndex = bottomAnchorIndex - ChatScrollUiFlow.BOTTOM_EDGE_PRELOAD_ITEM_COUNT
    // 用户已经能看到列表末尾附近时不再先跳到预加载位置, 避免视觉上"先被甩到上方再滚下来"
    if (this.deps.getLastVisibleIndex() >= preloadIndex) {
      return false
    }
    try {
      this.deps.scroller.scrollToIndex(preloadIndex, false, ScrollAlign.START)
      return true
    } catch (_error) {
      return false
    }
  }

  private scrollBottomEdgeWithAnimation(): void {
    this.deps.onAnimate(ChatScrollUiFlow.BOTTOM_EDGE_ANIMATION_DURATION_MS, Curve.EaseOut, () => {
      this.scrollBottomEdge()
    })
  }

  private scrollBottomEdgeFromPreloadPosition(): void {
    this.pendingBottomEdgePreloadActive = false
    if (!this.scrollNearBottomEdgeForPreload()) {
      this.scrollBottomEdgeWithAnimation()
      return
    }
    this.pendingBottomEdgePreloadActive = true
    setTimeout(() => {
      this.pendingBottomEdgePreloadActive = false
      if (this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
        return
      }
      this.scrollBottomEdgeWithAnimation()
      this.captureBottomScrollBaseline()
    }, ChatScrollUiFlow.BOTTOM_EDGE_PRELOAD_SETTLE_MS)
  }

  private setPendingEdgeScrollTarget(target: number): void {
    this.pendingEdgeScrollTarget = target
    this.pendingEdgeScrollCorrectionCount = 0
    this.pendingEdgeScrollCorrectionDeadline = target === ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE ?
      0 :
      Date.now() + ChatScrollUiFlow.EDGE_SCROLL_CORRECTION_WINDOW_MS
  }

  private clearPendingEdgeScrollTarget(): void {
    this.pendingEdgeScrollTarget = ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE
    this.pendingEdgeScrollCorrectionCount = 0
    this.pendingEdgeScrollCorrectionDeadline = 0
    this.pendingBottomEdgePreloadActive = false
  }

  private clearPendingBottomScrollTarget(): void {
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      this.clearPendingEdgeScrollTarget()
    }
  }

  private clearPendingIndexedScrollPhaseTimer(): void {
    if (this.pendingIndexedScrollPhaseTimerId < 0) {
      return
    }
    clearTimeout(this.pendingIndexedScrollPhaseTimerId)
    this.pendingIndexedScrollPhaseTimerId = -1
  }

  private clearPendingIndexedScrollTarget(): void {
    this.clearPendingIndexedScrollPhaseTimer()
    this.pendingIndexedScrollTarget = ChatScrollUiFlow.INDEXED_SCROLL_TARGET_NONE
    this.pendingIndexedScrollAlign = ScrollAlign.CENTER
    this.pendingIndexedScrollOffset = 0
    this.pendingIndexedScrollCorrectionCount = 0
    this.pendingIndexedScrollCorrectionDeadline = 0
    this.pendingIndexedScrollPhase = ChatScrollUiFlow.INDEXED_SCROLL_PHASE_NONE
    this.pendingIndexedTargetLastHeight = 0
    this.pendingIndexedTargetStableTickCount = 0
  }

  private isAtTopBoundary(): boolean {
    return this.deps.getIsAtTop() || this.normalizeScrollOffset(this.deps.syncCurrentScrollOffset()) <= 0
  }

  private isAtBottomBoundary(): boolean {
    const bottomAnchorIndex = this.deps.getBottomAnchorIndex()
    return this.deps.syncIsAtBottomBoundary() ||
      (bottomAnchorIndex >= 0 && this.deps.getLastVisibleIndex() >= bottomAnchorIndex)
  }

  private isAtBottomEdgeBoundary(): boolean {
    return this.deps.syncIsAtBottomBoundary()
  }

  private hasPendingIndexedScrollTarget(): boolean {
    return this.pendingIndexedScrollTarget !== ChatScrollUiFlow.INDEXED_SCROLL_TARGET_NONE
  }

  private isPendingIndexedScrollTargetVisible(): boolean {
    if (!this.hasPendingIndexedScrollTarget()) {
      return false
    }
    const firstVisible = this.deps.getFirstVisibleIndex()
    const lastVisible = this.deps.getLastVisibleIndex()
    return firstVisible <= this.pendingIndexedScrollTarget && this.pendingIndexedScrollTarget <= lastVisible
  }

  private markPendingEdgeScrollCorrectionIssued(): boolean {
    if (Date.now() > this.pendingEdgeScrollCorrectionDeadline ||
      this.pendingEdgeScrollCorrectionCount >= ChatScrollUiFlow.EDGE_SCROLL_CORRECTION_MAX_COUNT) {
      this.clearPendingEdgeScrollTarget()
      return false
    }
    this.pendingEdgeScrollCorrectionCount++
    return true
  }

  private markPendingIndexedScrollCorrectionIssued(): boolean {
    if (Date.now() > this.pendingIndexedScrollCorrectionDeadline ||
      this.pendingIndexedScrollCorrectionCount >= ChatScrollUiFlow.INDEXED_SCROLL_CORRECTION_MAX_COUNT) {
      this.clearPendingIndexedScrollTarget()
      return false
    }
    this.pendingIndexedScrollCorrectionCount++
    return true
  }

  private scrollPendingIndexedTarget(animated: boolean, align: ScrollAlign, useOffset: boolean = true): boolean {
    if (!this.hasPendingIndexedScrollTarget()) {
      return false
    }
    try {
      if (useOffset && this.pendingIndexedScrollOffset > 0) {
        this.deps.scroller.scrollToIndex(this.pendingIndexedScrollTarget, animated, align, {
          extraOffset: LengthMetrics.vp(-this.pendingIndexedScrollOffset)
        })
      } else {
        this.deps.scroller.scrollToIndex(this.pendingIndexedScrollTarget, animated, align)
      }
      return true
    } catch (_error) {
      this.clearPendingIndexedScrollTarget()
      return false
    }
  }

  private issuePendingIndexedFineTune(animated: boolean): boolean {
    if (!this.hasPendingIndexedScrollTarget()) {
      return false
    }
    if (this.pendingIndexedScrollPhase !== ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE) {
      return false
    }
    if (!this.markPendingIndexedScrollCorrectionIssued()) {
      return false
    }
    if (!this.isPendingIndexedScrollTargetVisible()) {
      return this.scrollPendingIndexedTarget(false, ScrollAlign.CENTER, false)
    }
    return this.scrollPendingIndexedTarget(animated, this.pendingIndexedScrollAlign, true)
  }

  private schedulePendingIndexedFineTuneClear(): void {
    this.clearPendingIndexedScrollPhaseTimer()
    const expectedTarget = this.pendingIndexedScrollTarget
    this.pendingIndexedScrollPhaseTimerId = setTimeout(() => {
      this.pendingIndexedScrollPhaseTimerId = -1
      if (!this.hasPendingIndexedScrollTarget() ||
        this.pendingIndexedScrollTarget !== expectedTarget ||
        this.pendingIndexedScrollPhase !== ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE) {
        return
      }
      this.clearPendingIndexedScrollTarget()
    }, ChatScrollUiFlow.INDEXED_SCROLL_FINE_TUNE_WINDOW_MS)
  }

  private schedulePendingIndexedStableFallback(delayMs: number): void {
    this.clearPendingIndexedScrollPhaseTimer()
    const expectedTarget = this.pendingIndexedScrollTarget
    this.pendingIndexedScrollPhaseTimerId = setTimeout(() => {
      this.pendingIndexedScrollPhaseTimerId = -1
      if (!this.hasPendingIndexedScrollTarget() ||
        this.pendingIndexedScrollTarget !== expectedTarget ||
        this.pendingIndexedScrollPhase !== ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_STABLE) {
        return
      }
      this.startPendingIndexedFineTune(false)
    }, delayMs)
  }

  private enterPendingIndexedWaitStable(measuredHeight: number = 0): void {
    if (!this.hasPendingIndexedScrollTarget()) {
      return
    }
    this.pendingIndexedScrollPhase = ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_STABLE
    this.pendingIndexedTargetLastHeight = measuredHeight > 0 ? measuredHeight : 0
    this.pendingIndexedTargetStableTickCount = 0
    this.schedulePendingIndexedStableFallback(measuredHeight > 0 ?
      ChatScrollUiFlow.INDEXED_SCROLL_WAIT_STABLE_TIMEOUT_MS :
      ChatScrollUiFlow.INDEXED_SCROLL_UNMEASURED_FALLBACK_MS)
  }

  private startPendingIndexedFineTune(animated: boolean): boolean {
    if (!this.hasPendingIndexedScrollTarget()) {
      return false
    }
    this.clearPendingIndexedScrollPhaseTimer()
    this.pendingIndexedScrollPhase = ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE
    this.pendingIndexedScrollCorrectionCount = 0
    this.pendingIndexedScrollCorrectionDeadline = Date.now() +
      ChatScrollUiFlow.INDEXED_SCROLL_FINE_TUNE_WINDOW_MS
    const didScroll = this.scrollPendingIndexedTarget(animated, this.pendingIndexedScrollAlign, true)
    if (didScroll) {
      this.schedulePendingIndexedFineTuneClear()
    }
    return didScroll
  }

  private handlePendingIndexedMeasuredHeight(measuredHeight: number): void {
    if (measuredHeight <= 0) {
      return
    }
    if (this.pendingIndexedTargetLastHeight <= 0) {
      this.pendingIndexedTargetLastHeight = measuredHeight
      this.pendingIndexedTargetStableTickCount = 0
      this.schedulePendingIndexedStableFallback(ChatScrollUiFlow.INDEXED_SCROLL_WAIT_STABLE_TIMEOUT_MS)
      return
    }
    const heightDelta = Math.abs(measuredHeight - this.pendingIndexedTargetLastHeight)
    this.pendingIndexedTargetLastHeight = measuredHeight
    if (heightDelta < ChatScrollUiFlow.INDEXED_SCROLL_STABLE_HEIGHT_DELTA_VP) {
      this.pendingIndexedTargetStableTickCount++
    } else {
      this.pendingIndexedTargetStableTickCount = 0
    }
    if (this.pendingIndexedTargetStableTickCount >= ChatScrollUiFlow.INDEXED_SCROLL_STABLE_TICK_TARGET) {
      this.startPendingIndexedFineTune(false)
    }
  }

  private correctPendingBottomEdge(): boolean {
    if (this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      return false
    }
    if (!this.markPendingEdgeScrollCorrectionIssued()) {
      return false
    }
    this.activateBottomLayoutPin()
    this.clearPinnedBottomAlignmentTimers()
    this.setIsAtBottom(true)
    this.setInputBarVisible(true)
    this.scrollBottomEdge()
    this.captureBottomScrollBaseline()
    return true
  }

  private verifyPendingTopScrollOnStop(): boolean {
    if (this.isAtTopBoundary()) {
      this.clearPendingEdgeScrollTarget()
      return true
    }
    if (this.markPendingEdgeScrollCorrectionIssued()) {
      this.scrollTopEdge()
    }
    return true
  }

  private verifyPendingBottomScrollOnStop(): boolean {
    if (this.pendingBottomEdgePreloadActive) {
      return true
    }
    if (this.isAtBottomEdgeBoundary()) {
      this.activateBottomLayoutPin()
      this.captureBottomScrollBaseline()
      this.clearPendingEdgeScrollTarget()
      return true
    }
    this.correctPendingBottomEdge()
    return true
  }

  alignToBottomAfterLayout(): void {
    this.clearInteractiveContentResizePending()
    this.activateBottomLayoutPin()
    setTimeout(() => {
      this.scrollBottomEdge()
    }, 0)
    setTimeout(() => {
      this.scrollBottomEdge()
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
        if (!this.pendingPinnedBottomAlignment || !this.shouldKeepBottomPinned()) {
          this.clearPinnedBottomAlignmentTimers()
          return
        }
        // V2 流式跟随用 animateTo 包裹, 避免 scrollEdge 瞬移产生的"跳动感";
        // pendingPinnedBottomAlignment 防抖保证同时间只有一组动画在跑
        this.deps.onAnimate(ChatScrollUiFlow.PIN_BOTTOM_ALIGNMENT_ANIMATION_DURATION_MS, Curve.EaseOut, () => {
          this.scrollBottomEdge()
        })
        this.captureBottomScrollBaseline()
      }, delays[i])
      this.pinnedBottomAlignmentTimerIds.push(timerId)
    }
    this.pinnedBottomAlignmentCompletionTimerId = setTimeout(() => {
      this.clearPinnedBottomAlignmentTimers()
    }, 120)
  }

  alignToBottomIfPinned(): void {
    if (!this.shouldKeepBottomPinned()) {
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
    const isAtEndBoundary = this.deps.syncIsAtBottomBoundary()
    const isMovingAwayFromBottom = isActiveScroll &&
      cumulativeOffset < lastScrollOffset - ChatScrollUiFlow.BOTTOM_AWAY_DELTA_VP
    const keepPinnedToBottom = !this.isBottomPinMuted() && !isMovingAwayFromBottom &&
      (isAtEndBoundary ||
      (this.deps.getIsAtBottom() && this.isWithinBottomTolerance(cumulativeOffset))
      )
    const effectiveOffset = keepPinnedToBottom ? this.resolveStableBottomOffset(cumulativeOffset) : cumulativeOffset

    this.setCurrentScrollOffset(effectiveOffset)
    const positionDelta = effectiveOffset - lastScrollOffset
    const hasProgrammaticBottomTarget = this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM
    const activeScrollAwayFromEnd = isActiveScroll && !hasProgrammaticBottomTarget &&
      !keepPinnedToBottom && !isAtEndBoundary
    const userScrolledAwayFromBottom = !keepPinnedToBottom &&
      (activeScrollAwayFromEnd || isMovingAwayFromBottom || (positionDelta < 0 &&
      (scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling)))

    if (userScrolledAwayFromBottom) {
      this.clearBottomFollowState(false)
    }

    if (keepPinnedToBottom) {
      this.activateBottomLayoutPin()
      this.setIsAtBottom(true)
      this.setInputBarVisible(true)
    } else if (activeScrollAwayFromEnd && this.deps.getIsAtBottom()) {
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
      this.deps.hasDraftContent() && this.shouldKeepBottomPinned()) {
      this.alignToBottomIfPinned()
    }
  }

  scrollToBottomWithAnimation(): void {
    this.clearInteractiveContentResizePending()
    this.clearPinnedBottomAlignmentTimers()
    this.clearBottomPinMute()
    this.activateBottomLayoutPin()
    this.setPendingEdgeScrollTarget(ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM)
    this.setIsAtBottom(true)
    this.setIsAtTop(false)
    this.setInputBarVisible(true)
    this.scrollBottomEdgeFromPreloadPosition()
    this.captureBottomScrollBaseline()
  }

  scrollToTopWithAnimation(): void {
    this.clearInteractiveContentResizePending()
    this.muteBottomPin(ChatScrollUiFlow.EDGE_SCROLL_BOTTOM_PIN_MUTE_MS)
    this.setPendingEdgeScrollTarget(ChatScrollUiFlow.EDGE_SCROLL_TARGET_TOP)
    this.setIsAtBottom(false)
    this.setInputBarVisible(true)
    this.scrollTopEdge()
  }

  public prepareForIndexedJump(): void {
    this.clearInteractiveContentResizePending()
    this.muteBottomPin(ChatScrollUiFlow.EDGE_SCROLL_BOTTOM_PIN_MUTE_MS)
    this.clearPendingEdgeScrollTarget()
    this.clearPendingIndexedScrollTarget()
    this.setIsAtTop(false)
    this.setIsAtBottom(false)
    this.setInputBarVisible(true)
  }

  public scrollToIndexWithStabilization(index: number, align: ScrollAlign, offset: number = 0): void {
    if (index < 0) {
      return
    }
    this.prepareForIndexedJump()
    this.pendingIndexedScrollTarget = index
    this.pendingIndexedScrollAlign = align
    this.pendingIndexedScrollOffset = this.normalizeScrollOffset(offset)
    this.pendingIndexedScrollPhase = ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_APPEAR
    this.scrollPendingIndexedTarget(false, ScrollAlign.CENTER, false)
    if (this.isPendingIndexedScrollTargetVisible()) {
      this.enterPendingIndexedWaitStable()
    }
  }

  public prepareForInteractiveContentResize(): void {
    this.interactiveContentResizePending = true
    this.clearBottomFollowState()
    this.setInputBarVisible(true)
  }

  public handleScrollIndexChanged(): void {
    if (!this.hasPendingIndexedScrollTarget()) {
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_APPEAR &&
      this.isPendingIndexedScrollTargetVisible()) {
      this.enterPendingIndexedWaitStable()
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE &&
      this.isPendingIndexedScrollTargetVisible()) {
      this.issuePendingIndexedFineTune(false)
    }
  }

  public handleIndexedTargetItemReady(listIndex: number): void {
    if (!this.hasPendingIndexedScrollTarget() || listIndex !== this.pendingIndexedScrollTarget) {
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_APPEAR) {
      this.enterPendingIndexedWaitStable()
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE) {
      this.issuePendingIndexedFineTune(false)
    }
  }

  public handleIndexedTargetItemMeasured(listIndex: number, measuredHeight: number): void {
    if (!this.hasPendingIndexedScrollTarget() || listIndex !== this.pendingIndexedScrollTarget) {
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_APPEAR) {
      this.enterPendingIndexedWaitStable(measuredHeight)
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_STABLE) {
      this.handlePendingIndexedMeasuredHeight(measuredHeight)
      return
    }
    if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_FINE_TUNE) {
      this.issuePendingIndexedFineTune(false)
    }
  }

  handleScrollStart(): void {
    this.clearInteractiveContentResizePending()
    if (this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_NONE) {
      return
    }
    this.clearPendingIndexedScrollTarget()
    this.clearPinnedBottomAlignmentTimers()
    this.clearBottomLayoutPin()
  }

  handleScrollStop(): boolean {
    if (this.hasPendingIndexedScrollTarget()) {
      if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_APPEAR) {
        if (this.isPendingIndexedScrollTargetVisible()) {
          this.enterPendingIndexedWaitStable()
        } else {
          this.scrollPendingIndexedTarget(false, ScrollAlign.CENTER, false)
        }
        return true
      }
      if (this.pendingIndexedScrollPhase === ChatScrollUiFlow.INDEXED_SCROLL_PHASE_WAIT_STABLE) {
        return true
      }
      this.issuePendingIndexedFineTune(false)
      return true
    }
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
    if (this.interactiveContentResizePending &&
      this.pendingEdgeScrollTarget !== ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      this.clearBottomFollowState()
      this.setInputBarVisible(true)
      if (!this.deps.syncIsAtBottomBoundary()) {
        this.clearInteractiveContentResizePending()
      }
      return
    }
    if (this.isBottomPinMuted()) {
      return
    }
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      if (this.pendingBottomEdgePreloadActive) {
        this.activateBottomLayoutPin()
        this.setIsAtBottom(true)
        this.setInputBarVisible(true)
        return
      }
      if (this.isAtBottomEdgeBoundary()) {
        this.activateBottomLayoutPin()
        this.captureBottomScrollBaseline()
        this.clearPendingEdgeScrollTarget()
        return
      }
      this.activateBottomLayoutPin()
      this.setIsAtBottom(true)
      this.setInputBarVisible(true)
      this.schedulePinnedBottomAlignmentAfterLayout()
      return
    }
    if (!this.shouldKeepBottomPinned()) {
      if (this.deps.syncIsAtBottomBoundary()) {
        this.activateBottomLayoutPin()
        this.setIsAtBottom(true)
        this.setInputBarVisible(true)
        this.captureBottomScrollBaseline()
      }
      return
    }
    this.activateBottomLayoutPin()
    this.clearPinnedBottomAlignmentTimers()
    this.setIsAtBottom(true)
    this.setInputBarVisible(true)
    this.scrollBottomEdge()
    this.captureBottomScrollBaseline()
  }

  scrollPageUpWithAnimation(): void {
    this.clearInteractiveContentResizePending()
    this.muteBottomPin(ChatScrollUiFlow.PAGE_SCROLL_BOTTOM_PIN_MUTE_MS)
    this.clearPendingBottomScrollTarget()
    this.setIsAtBottom(false)
    this.setInputBarVisible(true)
    this.deps.scroller.scrollPage({ next: false })
  }

  scrollPageDownWithAnimation(): void {
    this.clearInteractiveContentResizePending()
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
    this.clearInteractiveContentResizePending()
    const cumulativeOffset = this.deps.syncCurrentScrollOffset()
    this.deps.setLastScrollOffset(cumulativeOffset)
    this.activateBottomLayoutPin()
    this.setIsAtBottom(true)
    this.setInputBarVisible(true)
    this.captureBottomScrollBaseline()
    if (this.pendingEdgeScrollTarget === ChatScrollUiFlow.EDGE_SCROLL_TARGET_BOTTOM) {
      this.clearPendingEdgeScrollTarget()
    }
  }
}
