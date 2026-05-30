import uiEffect from '@ohos.graphics.uiEffect'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  BlurStrategy,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  hdsEffect,
  hdsMaterial
} from '@kit.UIDesignKit'
import { getAppUiState } from '../state/AppUiState'
import { withColorAlpha } from './ColorAlphaUtils'

const STATUS_BAR_CONTENT_LIGHT: string = '#1F2329'
const STATUS_BAR_CONTENT_DARK: string = '#F5F7FA'

export function buildPointLightBorderEffect(sourceBright: boolean = false): uiEffect.VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({
      sourceType: sourceBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
    })
    .buildEffect()
}

export function buildDualEdgeFlowLightBorderEffect(): uiEffect.VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .shaderEffect({
      effectType: hdsEffect.EffectType.DUAL_EDGE_FLOW_LIGHT,
      animation: {
        duration: 4000,
        iterations: -1,
        autoPlay: true
      },
      params: {
        firstEdgeFlowLight: {
          startPos: 0,
          endPos: 1,
          color: '#1AD0F1'
        },
        secondEdgeFlowLight: {
          startPos: 0.5,
          endPos: 1.5,
          color: '#FFA4E5'
        }
      }
    })
    .buildEffect()
}

export class HdsTopNavigationBlurOptions {
  startPaddingVp: number = 0
  endPaddingVp: number = 0
  materialType: number = 100
  materialLevel: number = 10
  windowWidthVp: number = 0
  windowHeightVp: number = 0
  maskExtraHeightVp: number = 20
  blurEffectiveEndOffsetVp: number = 28
  stackBuilder: () => void = (): void => {}
}

export function getHdsTopNavigationMaskExtraHeight(windowWidthVp: number, windowHeightVp: number,
  portraitHeightVp: number = 20, landscapeHeightVp: number = 16): number {
  return windowWidthVp > windowHeightVp ? landscapeHeightVp : portraitHeightVp
}

export function getHdsTopNavigationBlurEffectiveEndOffset(windowWidthVp: number, windowHeightVp: number): number {
  return windowWidthVp > windowHeightVp ? 20 : 28
}

export function getHdsTopNavigationContentTopPadding(topAvoidHeightVp: number, windowWidthVp: number,
  windowHeightVp: number, titleHeightVp: number = 56): number {
  return topAvoidHeightVp + titleHeightVp + getHdsTopNavigationMaskExtraHeight(windowWidthVp, windowHeightVp)
}

export function getHdsTopNavigationScrollEffectType(materialType: number): ScrollEffectType {
  if (materialType === 0) {
    return ScrollEffectType.GRADIENT_BLUR
  }
  return ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
}

export function getHdsStatusBarContentColor(): string {
  return getAppUiState().isDarkMode ? STATUS_BAR_CONTENT_DARK : STATUS_BAR_CONTENT_LIGHT
}

export function getHdsTopNavigationInitialBlurRadius(materialType: number): number {
  return materialType === 0 ? 0 : 8
}

function getHdsTopNavigationOriginBackgroundColor(): string {
  return withColorAlpha(getAppUiState().themeBackground, '00')
}

function getHdsTopNavigationScrolledBackgroundColor(): string {
  return withColorAlpha(getAppUiState().themeBackground, 'E6')
}

export function getHdsTopNavigationBlurRadius(materialType: number, materialLevel: number,
  windowWidthVp: number, windowHeightVp: number): number {
  if (materialType === 0) {
    return 0
  }
  const isLandscape = windowWidthVp > windowHeightVp
  if (materialLevel === 0) {
    return isLandscape ? 20 : 26
  }
  if (materialLevel === 1) {
    return isLandscape ? 18 : 22
  }
  if (materialLevel === 2) {
    return isLandscape ? 14 : 18
  }
  return isLandscape ? 16 : 22
}

export function buildHdsTopNavigationTitleBarOptions(
  options: HdsTopNavigationBlurOptions): HdsNavigationTitleBarOptions {
  return {
    padding: {
      start: LengthMetrics.vp(options.startPaddingVp),
      end: LengthMetrics.vp(options.endPaddingVp)
    },
    content: {
      title: {
        mainTitle: ' '
      },
      stackBuilder: options.stackBuilder
    },
    style: {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: getHdsTopNavigationScrollEffectType(options.materialType),
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(options.blurEffectiveEndOffsetVp)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: getHdsTopNavigationOriginBackgroundColor(),
          maskExtraHeight: options.maskExtraHeightVp,
          blurRadius: getHdsTopNavigationInitialBlurRadius(options.materialType)
        },
        contentStyle: {
          menuStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          },
          backIconStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: getHdsTopNavigationScrolledBackgroundColor(),
          maskExtraHeight: options.maskExtraHeightVp,
          blurRadius: getHdsTopNavigationBlurRadius(options.materialType, options.materialLevel, options.windowWidthVp,
            options.windowHeightVp)
        },
        contentStyle: {
          menuStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          },
          backIconStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      blurStrategy: BlurStrategy.ENABLE,
      systemMaterialEffect: {
        materialType: options.materialType as hdsMaterial.MaterialType,
        materialLevel: options.materialLevel as hdsMaterial.MaterialLevel
      }
    },
    avoidLayoutSafeArea: true,
    enableComponentSafeArea: false
  }
}

export function buildHdsTopNavigationTitleBarOptionsForPage(materialType: number, materialLevel: number,
  windowWidthVp: number, windowHeightVp: number, stackBuilder: () => void): HdsNavigationTitleBarOptions {
  const options = new HdsTopNavigationBlurOptions()
  options.materialType = materialType
  options.materialLevel = materialLevel
  options.windowWidthVp = windowWidthVp
  options.windowHeightVp = windowHeightVp
  options.maskExtraHeightVp = getHdsTopNavigationMaskExtraHeight(windowWidthVp, windowHeightVp)
  options.blurEffectiveEndOffsetVp = getHdsTopNavigationBlurEffectiveEndOffset(windowWidthVp, windowHeightVp)
  options.stackBuilder = stackBuilder
  return buildHdsTopNavigationTitleBarOptions(options)
}

export function createHdsTitleBarSymbolIcon(symbol: Resource, fontSize: number = 20): SymbolGlyphModifier {
  const icon = new SymbolGlyphModifier(symbol)
  icon.fontSize(fontSize)
  icon.fontColor([$r('sys.color.icon_primary')])
  return icon
}

export function createHdsTitleBarBackIcon(action: () => void): HdsNavigationBackButtonItemOptions {
  return {
    icon: createHdsTitleBarSymbolIcon($r('sys.symbol.chevron_left'), 20),
    action: action
  }
}

export function buildHdsTopNavigationTitleBarOptionsForNativePage(materialType: number, materialLevel: number,
  windowWidthVp: number, windowHeightVp: number, title: ResourceStr, backAction: () => void,
  menuItems: Array<HdsNavigationMenuItemOptions> = [], menuMaxCount: number = 3): HdsNavigationTitleBarOptions {
  const options = new HdsTopNavigationBlurOptions()
  options.materialType = materialType
  options.materialLevel = materialLevel
  options.windowWidthVp = windowWidthVp
  options.windowHeightVp = windowHeightVp
  options.maskExtraHeightVp = getHdsTopNavigationMaskExtraHeight(windowWidthVp, windowHeightVp)
  options.blurEffectiveEndOffsetVp = getHdsTopNavigationBlurEffectiveEndOffset(windowWidthVp, windowHeightVp)
  const titleBarOptions = buildHdsTopNavigationTitleBarOptions(options)
  titleBarOptions.content = {
    title: {
      mainTitle: title
    },
    backIcon: createHdsTitleBarBackIcon(backAction)
  }
  if (menuItems.length > 0) {
    titleBarOptions.content.menu = {
      maxCount: menuMaxCount,
      value: menuItems
    }
  }
  return titleBarOptions
}

/**
 * 把设置中的高级材质档位 (materialType / materialLevel) 映射到 BlurStyle。
 * 用于不支持 hdsMaterial.systemMaterialEffect 的组件 (如 HdsSnackBar、ChatToolbar
 * 等使用 backgroundBlurStyle 的浮层) 跟随用户档位。
 *
 * 档位语义:
 *   materialType: 0 = NONE(关闭) / 100 = ADAPTIVE / 101 = IMMERSIVE
 *   materialLevel: 0 = 精致 / 1 = 温润 / 2 = 平滑 / 10 = 自适应
 */
export function getBlurStyleForMaterial(materialType: number, materialLevel: number): BlurStyle {
  if (materialType === 0) {
    return BlurStyle.NONE
  }
  if (materialLevel === 0) {
    return BlurStyle.COMPONENT_ULTRA_THIN
  }
  if (materialLevel === 1) {
    return BlurStyle.COMPONENT_THIN
  }
  if (materialLevel === 2) {
    return BlurStyle.COMPONENT_REGULAR
  }
  // 10 = 自适应, 维持原 SnackBar 默认观感 (REGULAR)
  return BlurStyle.COMPONENT_REGULAR
}

/**
 * 与 getBlurStyleForMaterial 配套, 决定 BlurStrategy。
 * materialType=NONE 时直接禁用模糊策略, 否则走 ADAPTIVE 让系统按性能/电量动态调节。
 */
export function getBlurStrategyForMaterial(materialType: number): BlurStrategy {
  if (materialType === 0) {
    return BlurStrategy.DISABLE
  }
  return BlurStrategy.ADAPTIVE
}

/**
 * 直接读取当前 AppUiState 的高级材质档位并返回 BlurStyle, 调用方无需关心档位字段。
 */
export function getCurrentMaterialBlurStyle(): BlurStyle {
  const state = getAppUiState()
  return getBlurStyleForMaterial(state.materialType, state.materialLevel)
}

/**
 * 直接读取当前 AppUiState 的高级材质档位并返回 BlurStrategy。
 */
export function getCurrentMaterialBlurStrategy(): BlurStrategy {
  const state = getAppUiState()
  return getBlurStrategyForMaterial(state.materialType)
}
