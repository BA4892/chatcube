/**
 * 接收方:扫到 QR 后弹出,输入密码 → 解密 → 预览 → 导入。
 * 第 3 步 MVP:总是创建新 provider(id = custom_${Date.now()}), 不覆盖现有。
 * 第 4 步会加 ID 冲突 radio / 密码错锁 / baseUrl 白名单警告等保护逻辑。
 */
import { ApiStyle, ModelProvider, OpenAITransport, ProviderType } from '../../models/ChatModels'
import { PASSWORD_MAX_LEN, PASSWORD_MIN_LEN, ProviderShareDataV1 } from '../../models/ProviderSharePayload'
import { getProviderShareCodec } from '../../services/ProviderShareCodec'
import { getPresetProviders } from '../../config/PresetProviders'
import { ProviderViewModel } from '../../viewmodels/ProviderViewModel'
import { ServiceRegistry } from '../../services/ServiceRegistry'
import { showToast } from '../../utils/ToastUtil'
import { pickLocalizedText } from '../../utils/LocalizedTextUtils'
import { getAppUiState } from '../../state/AppUiState'

function stringToProviderType(typeStr: string): ProviderType {
  if (typeStr === 'openai') {
    return ProviderType.OPENAI
  } else if (typeStr === 'anthropic') {
    return ProviderType.ANTHROPIC
  } else if (typeStr === 'azure') {
    return ProviderType.AZURE
  } else if (typeStr === 'deepseek') {
    return ProviderType.DEEPSEEK
  } else if (typeStr === 'ollama') {
    return ProviderType.OLLAMA
  } else if (typeStr === 'lmstudio') {
    return ProviderType.LMSTUDIO
  } else if (typeStr === 'custom') {
    return ProviderType.CUSTOM
  }
  return ProviderType.CUSTOM
}

function stringToApiStyle(styleStr: string): ApiStyle {
  if (styleStr === 'anthropic') {
    return ApiStyle.ANTHROPIC
  } else if (styleStr === 'google') {
    return ApiStyle.GOOGLE
  }
  return ApiStyle.OPENAI
}

function stringToOpenAITransport(transportStr: string): OpenAITransport {
  if (transportStr === 'responses') {
    return OpenAITransport.RESPONSES
  }
  return OpenAITransport.CHAT_COMPLETIONS
}

function extractHost(url: string): string {
  const lower = url.toLowerCase()
  const schemeIdx = lower.indexOf('://')
  const hostStart = schemeIdx >= 0 ? schemeIdx + 3 : 0
  const slashAfterHost = lower.indexOf('/', hostStart)
  return slashAfterHost >= 0 ? lower.substring(hostStart, slashAfterHost) : lower.substring(hostStart)
}

function isPresetBaseUrl(url: string): boolean {
  if (url === '') {
    return false
  }
  const targetHost = extractHost(url)
  if (targetHost === '') {
    return false
  }
  const presets = getPresetProviders()
  for (let i = 0; i < presets.length; i++) {
    if (extractHost(presets[i].baseUrl) === targetHost) {
      return true
    }
  }
  return false
}

@ComponentV2
export struct ProviderImportPreviewSheet {
  @Param payload: string = ''
  @Event onClose: () => void = () => {}
  @Event onImported: (providerId: string) => void = (_id: string) => {}

  @Local password: string = ''
  @Local errorMessage: string = ''
  @Local isWorking: boolean = false
  @Local decoded: ProviderShareDataV1 | null = null

  private providerViewModel: ProviderViewModel = ServiceRegistry.provider()

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private isPasswordValid(): boolean {
    if (this.password.length < PASSWORD_MIN_LEN || this.password.length > PASSWORD_MAX_LEN) {
      return false
    }
    for (let i = 0; i < this.password.length; i++) {
      const code = this.password.charCodeAt(i)
      if (code < 0x30 || code > 0x39) {
        return false
      }
    }
    return true
  }

  private async onTapDecrypt(): Promise<void> {
    if (this.isWorking || !this.isPasswordValid() || this.payload === '') {
      return
    }
    this.isWorking = true
    this.errorMessage = ''
    try {
      const result = await getProviderShareCodec().decode(this.payload, this.password)
      if (!result.ok || result.data === null) {
        if (result.error === 'wrong_password') {
          this.errorMessage = pickLocalizedText('密码错误,请重试', 'Wrong password, try again')
        } else if (result.error === 'invalid_envelope') {
          this.errorMessage = pickLocalizedText('二维码内容无效', 'Invalid QR content')
        } else {
          this.errorMessage = pickLocalizedText('解密失败,请重试', 'Decryption failed')
        }
        return
      }
      this.decoded = result.data
    } catch (err) {
      console.error('ProviderImportPreviewSheet', `decrypt failed: ${JSON.stringify(err)}`)
      this.errorMessage = pickLocalizedText('解密失败,请重试', 'Decryption failed')
    } finally {
      this.isWorking = false
    }
  }

  private async onTapImport(): Promise<void> {
    if (this.isWorking || this.decoded === null) {
      return
    }
    this.isWorking = true
    try {
      const data = this.decoded
      const providerType = stringToProviderType(data.t)
      const apiStyle = stringToApiStyle(data.as)
      const newId = `custom_${Date.now()}`
      const provider = new ModelProvider(
        newId,
        data.n,
        providerType,
        '',
        $r('app.color.primary'),
        data.url,
        apiStyle
      )
      provider.apiKey = data.k
      provider.requiresApiKey = providerType !== ProviderType.OLLAMA && providerType !== ProviderType.LMSTUDIO
      provider.isPreset = false
      provider.apiPath = data.ap
      provider.openaiTransport = stringToOpenAITransport(data.ot)
      provider.customHeadersJson = data.ch
      await this.providerViewModel.saveProvider(provider, true)
      await this.providerViewModel.updateProviderEnabled(newId, true)
      showToast(this.getUIContext(),
        pickLocalizedText(`已添加: ${data.n}`, `Added: ${data.n}`))
      this.onImported(newId)
      this.onClose()
    } catch (err) {
      console.error('ProviderImportPreviewSheet', `import failed: ${JSON.stringify(err)}`)
      showToast(this.getUIContext(),
        pickLocalizedText('导入失败,请重试', 'Import failed, please retry'))
    } finally {
      this.isWorking = false
    }
  }

  private apiKeyStatus(data: ProviderShareDataV1): string {
    if (data.k === '') {
      return pickLocalizedText('未包含,稍后填写', 'Not included, fill it later')
    }
    return pickLocalizedText('已包含', 'Included')
  }

  @Builder
  HeaderRow() {
    Row() {
      Text($r('app.string.provider_import_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(16)
          .fontColor([$r('app.color.text_secondary')])
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor($r('app.color.divider'))
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onClose()
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
  }

  @Builder
  PasswordPhase() {
    Column({ space: 14 }) {
      Text($r('app.string.provider_import_password_hint'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Column({ space: 6 }) {
        Text($r('app.string.provider_share_password_label'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({ text: this.password, placeholder: $r('app.string.provider_share_password_placeholder') })
          .type(InputType.Number)
          .maxLength(PASSWORD_MAX_LEN)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface'))
          .borderRadius(10)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            let digits = ''
            for (let i = 0; i < value.length && digits.length < PASSWORD_MAX_LEN; i++) {
              const code = value.charCodeAt(i)
              if (code >= 0x30 && code <= 0x39) {
                digits += value.charAt(i)
              }
            }
            if (digits !== value) {
              this.password = digits
            } else {
              this.password = value
            }
            this.errorMessage = ''
          })
      }
      .width('100%')

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }

      Button() {
        Row({ space: 8 }) {
          if (this.isWorking) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(Color.White)
          }
          Text($r('app.string.provider_import_decrypt'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .type(ButtonType.Capsule)
      .width('100%')
      .height(44)
      .backgroundColor(this.isPasswordValid() && !this.isWorking
        ? this.themePrimary
        : $r('app.color.divider'))
      .enabled(this.isPasswordValid() && !this.isWorking)
      .onClick(() => {
        void this.onTapDecrypt()
      })
    }
    .width('100%')
  }

  @Builder
  PreviewPhase(data: ProviderShareDataV1) {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Row() {
          Text($r('app.string.provider_name'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(data.n)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Row() {
          Text('baseUrl')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(data.url)
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.End)
            .margin({ left: 12 })
        }
        .width('100%')

        Row() {
          Text('API Key')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.apiKeyStatus(data))
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.surface'))

      if (!isPresetBaseUrl(data.url)) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(16)
            .fontColor([$r('app.color.status_error')])
          Text($r('app.string.provider_import_custom_url_warning'))
            .fontSize(12)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .borderRadius(10)
        .backgroundColor($r('app.color.divider'))
        .alignItems(VerticalAlign.Top)
      }

      Row({ space: 12 }) {
        Button() {
          Text($r('app.string.cancel'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
        }
        .type(ButtonType.Capsule)
        .layoutWeight(1)
        .height(44)
        .backgroundColor($r('app.color.divider'))
        .enabled(!this.isWorking)
        .onClick(() => {
          this.onClose()
        })

        Button() {
          Row({ space: 6 }) {
            if (this.isWorking) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(Color.White)
            }
            Text($r('app.string.provider_import_confirm'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
        }
        .type(ButtonType.Capsule)
        .layoutWeight(1)
        .height(44)
        .backgroundColor(this.isWorking ? $r('app.color.divider') : this.themePrimary)
        .enabled(!this.isWorking)
        .onClick(() => {
          void this.onTapImport()
        })
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      this.HeaderRow()
      Scroll() {
        Column() {
          if (this.decoded === null) {
            this.PasswordPhase()
          } else {
            this.PreviewPhase(this.decoded)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }
}
