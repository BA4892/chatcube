import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0002
const TAG = 'ThrottleUtil'

/**
 * 流式 emit 抽象. ThrottleUtil 与 V2 的 TypewriterFlusher 都实现此接口,
 * 这样 ChatViewModel 可以在不改业务代码的情况下在两种节流策略之间切换.
 *
 * 语义:
 *   throttle(chunk, cb): 喂入一段流式增量, 由实现决定何时调用 cb 推动 UI
 *   flush(cb):           立即吐完所有积压并通过 cb 一次性回传
 *   reset():             清空积压, 释放定时器/帧资源
 */
export interface StreamFlusher {
  throttle(content: string, callback: (content: string) => void): void
  flush(callback: (content: string) => void): void
  reset(): void
}

/**
 * 流式文本批量节流工具类。
 * Markdown 流式渲染默认按时间片批量刷新，避免逐字触发长文本解析和布局。
 */
export class ThrottleUtil implements StreamFlusher {
  // 上次执行时间
  private lastExecuteTime: number = 0
  // 待执行的内容缓存
  private pendingContent: string = ''
  // 节流定时器 ID
  private timerId: number = -1
  // 节流间隔（毫秒）
  private readonly interval: number

  constructor(interval: number = 150) {
    this.interval = interval
    hilog.debug(DOMAIN, TAG, '🚀 ThrottleUtil 初始化 (间隔: %{public}dms)', interval)
  }

  /**
   * 节流执行入口
   * @param content 新到达的流式文本片段
   * @param callback 触发 UI 更新的回调，参数为本次输出的字符片段
   */
  throttle(content: string, callback: (content: string) => void): void {
    this.pendingContent += content
    const now = Date.now()

    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }

    if (now - this.lastExecuteTime >= this.interval) {
      this.execute(callback)
    } else {
      const delay = this.interval - (now - this.lastExecuteTime)
      this.timerId = setTimeout(() => {
        this.execute(callback)
      }, delay)
      return
    }
  }

  /**
   * 执行回调并重置状态 (普通非打字机模式使用)
   */
  private execute(callback: (content: string) => void): void {
    if (this.pendingContent === '') {
      return
    }

    const contentToExecute = this.pendingContent
    this.pendingContent = ''
    this.lastExecuteTime = Date.now()
    this.timerId = -1

    callback(contentToExecute)
  }

  /**
   * 立即刷新（强制执行所有待处理内容）
   * 用于流式结束时，确保所有内容同步落盘，避免异步打字导致保存时数据不完整
   */
  flush(callback: (content: string) => void): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }

    // 立即合并剩余的所有字符
    const remaining = this.pendingContent
    this.pendingContent = ''
    this.lastExecuteTime = Date.now()

    if (remaining !== '') {
      callback(remaining)
    }
  }

  /**
   * 重置节流器状态
   */
  reset(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }
    this.pendingContent = ''
    this.lastExecuteTime = 0
    hilog.debug(DOMAIN, TAG, '🔄 节流器已重置')
  }
}

/**
 * 创建节流工具实例
 * @param interval 节流间隔（毫秒），默认 150ms
 * @returns ThrottleUtil 实例
 */
export function createThrottle(interval: number = 150): ThrottleUtil {
  return new ThrottleUtil(interval)
}
