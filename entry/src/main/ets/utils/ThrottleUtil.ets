import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0002
const TAG = 'ThrottleUtil'

/**
 * 节流与打字机平滑差值工具类。
 * Markdown 流式渲染默认按时间片批量刷新，避免逐字触发长文本解析和布局。
 */
export class ThrottleUtil {
  // 上次执行时间（非打字机节流模式使用）
  private lastExecuteTime: number = 0
  // 待执行的内容缓存（非打字机节流模式使用）
  private pendingContent: string = ''
  // 节流定时器 ID
  private timerId: number = -1
  // 节流间隔（毫秒）
  private readonly interval: number
  // 是否已启用
  private enabled: boolean = true

  // ============ 打字机平滑差值相关属性 ============
  // 是否开启打字机效果。Markdown 长文本实时渲染时逐字刷新会放大解析和布局成本，默认使用批量节流。
  private useTypewriter: boolean = false
  // 打字机待输出的字符缓冲区
  private typewriterBuffer: string = ''
  // 打字机定时器 ID
  private typewriterTimerId: number = -1
  // 打字机输出间隔（毫秒），一般 20ms - 30ms。20ms 即 1 秒打 50 个字，极度流畅且无卡顿。
  private readonly typewriterInterval: number = 20
  // 当前执行的回调函数
  private activeCallback: ((content: string) => void) | null = null

  constructor(interval: number = 150, useTypewriter: boolean = false) {
    this.interval = interval
    this.useTypewriter = useTypewriter
    hilog.debug(DOMAIN, TAG, '🚀 ThrottleUtil 初始化 (间隔: %{public}dms)', interval)
  }

  /**
   * 节流与打字机执行入口
   * @param content 新到达的流式文本片段
   * @param callback 触发 UI 更新的回调，参数为本次输出的字符片段
   */
  throttle(content: string, callback: (content: string) => void): void {
    if (!this.enabled) {
      callback(content)
      return
    }

    if (!this.useTypewriter) {
      // 普通非打字机节流逻辑
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
      }
      return
    }

    // 打字机平滑差值逻辑：直接送入打字机队列，零延迟立即开始逐字打出！
    if (content === '') {
      return
    }
    this.typewriterBuffer += content
    this.startTypewriter(callback)
  }

  /**
   * 启动/运行打字机定时器循环
   */
  private startTypewriter(callback: (content: string) => void): void {
    this.activeCallback = callback
    if (this.typewriterTimerId !== -1) {
      return
    }

    const tick = () => {
      if (this.typewriterBuffer.length === 0) {
        this.typewriterTimerId = -1
        return
      }

      // 精确的逐字控制：默认每次只输出 1 个字符，实现真正平滑的逐字流动感。
      // 只有在积压过多时（比如网络抖动导致大批字符瞬间到达），才自适应增加步长以追赶进度，避免视觉延迟。
      let step = 1
      const bufLen = this.typewriterBuffer.length
      if (bufLen > 50) {
        step = Math.ceil(bufLen / 10) // 严重积压（大于50字），快速追赶
      } else if (bufLen > 20) {
        step = 2 // 中度积压，每次打出 2 个字
      }

      const chunk = this.typewriterBuffer.substring(0, step)
      this.typewriterBuffer = this.typewriterBuffer.substring(step)

      if (this.activeCallback !== null) {
        this.activeCallback(chunk)
      }

      this.typewriterTimerId = setTimeout(tick, this.typewriterInterval)
    }

    this.typewriterTimerId = setTimeout(tick, this.typewriterInterval)
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
    if (this.typewriterTimerId !== -1) {
      clearTimeout(this.typewriterTimerId)
      this.typewriterTimerId = -1
    }

    // 立即合并剩余的所有字符
    const remaining = this.pendingContent + this.typewriterBuffer
    this.pendingContent = ''
    this.typewriterBuffer = ''
    this.lastExecuteTime = Date.now()
    this.activeCallback = null

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
    if (this.typewriterTimerId !== -1) {
      clearTimeout(this.typewriterTimerId)
      this.typewriterTimerId = -1
    }
    this.pendingContent = ''
    this.typewriterBuffer = ''
    this.lastExecuteTime = 0
    this.activeCallback = null
    hilog.debug(DOMAIN, TAG, '🔄 节流器与打字机已重置')
  }

  /**
   * 启用节流
   */
  enable(): void {
    this.enabled = true
    hilog.debug(DOMAIN, TAG, '✅ 节流已启用')
  }

  /**
   * 禁用节流
   */
  disable(): void {
    this.enabled = false
    hilog.debug(DOMAIN, TAG, '⛔ 节流已禁用')
  }

  /**
   * 检查是否有待处理的内容
   */
  hasPending(): boolean {
    return this.pendingContent !== '' || this.typewriterBuffer !== '' || this.timerId !== -1 || this.typewriterTimerId !== -1
  }
}

/**
 * 创建节流工具实例
 * @param interval 节流间隔（毫秒），默认 150ms
 * @returns ThrottleUtil 实例
 */
export function createThrottle(interval: number = 150, useTypewriter: boolean = false): ThrottleUtil {
  return new ThrottleUtil(interval, useTypewriter)
}
