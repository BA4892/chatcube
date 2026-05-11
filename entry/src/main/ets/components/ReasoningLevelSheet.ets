/**
 * 推理强度选择面板组件
 * 可被包到 bindSheet 里做底部弹出,同时也可以嵌入在普通页面里。
 *
 * UI: 标题 + 提示 + 每档一行的选项按钮(图标 + 名称 + 描述 + 选中描边)
 * 支持按 ReasoningControlMode 动态显隐分档
 * 支持 allowFollowGlobal 开关,用于助手设置页展示“跟随全局”档(传空串)
 */

import { ReasoningLevel } from '../models/ChatModels'
import { ReasoningControlMode } from '../services/registry/CompatibilityResolver'
import { getAppUiState } from '../state/AppUiState'

interface ReasoningLevelOption {
  value: string          // '' 表示跟随全局, 其余是 ReasoningLevel 枚举字符串
  title: Resource | string
  description: Resource | string
}

@ComponentV2
export struct ReasoningLevelSheet {
  // 当前已选,'' 代表跟随全局(仅 allowFollowGlobal=true 时有意义)
  @Param value: string = ReasoningLevel.OFF
  @Event $value: (next: string) => void = (_next: string) => {}

  @Param reasoningControlMode: ReasoningControlMode = ReasoningControlMode.EFFORT
  @Param reasoningXhighAvailable: boolean = false
  // 是否显示“跟随全局”选项;助手设置用 true,聊天页运行时用 false
  @Param allowFollowGlobal: boolean = false
  // 自动关闭回调,只有传入时才触发(bindSheet 场景下外部通常会把 $$showSheet 置 false)
  @Event onClose: () => void = () => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }

  private buildOptions(): ReasoningLevelOption[] {
    const list: ReasoningLevelOption[] = []
    if (this.allowFollowGlobal) {
      list.push({
        value: '',
        title: $r('app.string.assistant_reasoning_level_follow_global'),
        description: $r('app.string.assistant_reasoning_level_hint')
      })
    }
    list.push({
      value: ReasoningLevel.OFF,
      title: $r('app.string.reasoning_level_off'),
      description: $r('app.string.reasoning_level_off_hint')
    })
    list.push({
      value: ReasoningLevel.AUTO,
      title: $r('app.string.reasoning_level_auto'),
      description: $r('app.string.reasoning_level_auto_hint')
    })
    if (this.reasoningControlMode === ReasoningControlMode.EFFORT) {
      list.push({
        value: ReasoningLevel.LOW,
        title: $r('app.string.reasoning_level_low'),
        description: $r('app.string.reasoning_level_low_hint')
      })
      list.push({
        value: ReasoningLevel.MEDIUM,
        title: $r('app.string.reasoning_level_medium'),
        description: $r('app.string.reasoning_level_medium_hint')
      })
      list.push({
        value: ReasoningLevel.HIGH,
        title: $r('app.string.reasoning_level_high'),
        description: $r('app.string.reasoning_level_high_hint')
      })
      if (this.reasoningXhighAvailable) {
        list.push({
          value: ReasoningLevel.XHIGH,
          title: $r('app.string.reasoning_level_xhigh'),
          description: $r('app.string.reasoning_level_xhigh_hint')
        })
      }
    } else if (this.reasoningControlMode === ReasoningControlMode.HIGH_MAX) {
      list.push({
        value: ReasoningLevel.HIGH,
        title: $r('app.string.reasoning_level_high'),
        description: $r('app.string.reasoning_level_high_hint')
      })
      if (this.reasoningXhighAvailable) {
        list.push({
          value: ReasoningLevel.XHIGH,
          title: $r('app.string.reasoning_level_xhigh'),
          description: $r('app.string.reasoning_level_xhigh_hint')
        })
      }
    }
    return list
  }

  // 按强度映射图标;越高的档越饱和,方便用户快速区分
  private iconFor(value: string): Resource {
    if (value === ReasoningLevel.OFF || value === '') {
      return $r('sys.symbol.lightbulb_slash')
    }
    if (value === ReasoningLevel.AUTO) {
      return $r('sys.symbol.wand_and_stars')
    }
    return $r('sys.symbol.lightbulb')
  }

  // 选中描边颜色
  private borderColorFor(selected: boolean): ResourceColor {
    return selected ? this.themePrimary : $r('app.color.divider')
  }

  private titleColorFor(selected: boolean): ResourceColor {
    return selected ? this.themePrimary : $r('app.color.text_primary')
  }

  build() {
    Column() {
      // Header
      Column() {
        Text($r('app.string.reasoning_picker_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.reasoning_picker_hint'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })
      .alignItems(HorizontalAlign.Center)

      // Options
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.buildOptions(), (opt: ReasoningLevelOption, _index: number) => {
            Row({ space: 12 }) {
              SymbolGlyph(this.iconFor(opt.value))
                .fontSize(20)
                .fontColor([this.titleColorFor(this.value === opt.value)])

              Column() {
                Text(opt.title)
                  .fontSize(15)
                  .fontWeight(this.value === opt.value ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(this.titleColorFor(this.value === opt.value))
                Text(opt.description)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.value === opt.value) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(16)
                  .fontColor([this.themePrimary])
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.background'))
            .borderRadius(14)
            .border({
              width: this.value === opt.value ? 1.4 : 0.8,
              color: this.borderColorFor(this.value === opt.value)
            })
            .onClick(() => {
              this.$value(opt.value)
              this.onClose()
            })
          }, (opt: ReasoningLevelOption) => opt.value)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
