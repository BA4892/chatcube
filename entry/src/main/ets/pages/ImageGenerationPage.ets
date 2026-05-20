import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { ModelProvider } from '../models/ChatModels'
import { GeneratedMedia, ImageAspectRatio } from '../models/ImageGenerationModels'
import { ImageGenerationViewModel } from '../viewmodels/ImageGenerationViewModel'
import { ImagePromptBar } from '../components/imagegen/ImagePromptBar'
import { ImageResultGrid } from '../components/imagegen/ImageResultGrid'
import { ImageGalleryGrid } from '../components/imagegen/ImageGalleryGrid'
import { ImageGenerationSettingsSheet } from '../components/imagegen/ImageGenerationSettingsSheet'
import { ImageGenerationModelSheet } from '../components/imagegen/ImageGenerationModelSheet'
import { ImageGenerationPreviewRouteParams } from './ImageGenerationPreviewPage'
import { getAppUiState } from '../state/AppUiState'
import { AppStorageKeys } from '../config/AppStorageKeys'
import { saveFileImageToAlbum } from '../utils/RawfileImageSaveUtil'
import { showToast } from '../utils/ToastUtil'

const IMAGE_GENERATION_PREVIEW_ROUTE = 'ImageGenerationPreviewPage'
let imageGenerationPagePathStack: NavPathStack | null = null
let imageGenerationBackHandler: (() => boolean) | null = null

@Entry
@ComponentV2
struct ImageGenerationPage {
  @Local viewModel: ImageGenerationViewModel = ImageGenerationViewModel.getInstance()
  @Local currentTabIndex: number = 0
  @Local showSettingsSheet: boolean = false
  @Local showModelSheet: boolean = false
  @Local showDeleteSheet: boolean = false
  @Local showCancelSheet: boolean = false
  @Local pendingDeleteId: string = ''
  @Local activePreviewTransitionId: string = ''
  @Local previewSourceVisible: boolean = true
  @Local isPreviewRouteOpen: boolean = false

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private get windowWidthVp(): number {
    return getAppUiState().windowWidthVp
  }

  aboutToAppear(): void {
    AppStorage.setOrCreate(AppStorageKeys.ACTIVE_IMAGE_GENERATION_PAGE, true)
    imageGenerationBackHandler = (): boolean => {
      this.handleBack()
      return true
    }
    this.viewModel.loadInitialState().catch((error: Object): void => {
      console.error('ImageGenerationPage', `Load initial state failed: ${JSON.stringify(error)}`)
      this.viewModel.errorMessage = '图像生成页面初始化失败'
    })
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate(AppStorageKeys.ACTIVE_IMAGE_GENERATION_PAGE, false)
    if (imageGenerationBackHandler !== null) {
      imageGenerationBackHandler = null
    }
    imageGenerationPagePathStack = null
  }

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private getTopPadding(): number {
    return this.px2vp(getAppUiState().topAvoidHeight)
  }

  private getGalleryColumns(): number {
    return this.windowWidthVp >= 720 ? 3 : 2
  }

  private getSelectedProvider(): ModelProvider | null {
    for (let i = 0; i < this.viewModel.providers.length; i++) {
      const provider = this.viewModel.providers[i]
      if (provider.id === this.viewModel.selectedProviderId) {
        return provider
      }
    }
    return null
  }

  private getSelectedProviderIconType(): string {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.iconType : 'svg'
  }

  private getSelectedProviderIconPath(): string {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.iconPath : ''
  }

  private getSelectedProviderTextIcon(): string {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.textIcon : ''
  }

  private getSelectedProviderTextIconBgColor(): string {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.textIconBgColor : ''
  }

  private getSelectedProviderCustomImagePath(): string {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.customImagePath : ''
  }

  private getSelectedProviderBrandColor(): ResourceColor {
    const provider = this.getSelectedProvider()
    return provider !== null ? provider.brandColor : ''
  }

  private isEditingMode(): boolean {
    return this.viewModel.isCurrentRequestEditing()
  }

  private handleBack(): void {
    // 允许用户离开页面，任务在后台继续运行（ViewModel 是单例）
    // 想真正取消任务，请使用 prompt bar 上的取消按钮
    if (this.viewModel.isGenerating) {
      showToast(this.getUIContext(), this.isEditingMode() ?
        $r('app.string.image_generation_editing_in_background') :
        $r('app.string.image_generation_running_in_background'))
    }
    if (imageGenerationPagePathStack !== null && imageGenerationPagePathStack.size() > 0) {
      imageGenerationPagePathStack.pop()
    }
  }

  private async pickReferenceImages(): Promise<void> {
    try {
      const remaining = 4 - this.viewModel.referenceImages.length
      if (remaining <= 0) {
        showToast(this.getUIContext(), $r('app.string.image_generation_reference_limit'))
        return
      }
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      photoSelectOptions.maxSelectNumber = remaining
      const photoPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoPicker.select(photoSelectOptions)
      if (result.photoUris.length > 0) {
        await this.viewModel.addReferenceImageUris(result.photoUris)
      }
    } catch (error) {
      console.error('ImageGenerationPage', `Pick reference failed: ${JSON.stringify(error)}`)
      showToast(this.getUIContext(), $r('app.string.image_generation_reference_failed'))
    }
  }

  private openPreview(items: GeneratedMedia[], index: number): void {
    const images: string[] = []
    const transitionIds: string[] = []
    const aspectRatios: number[] = []
    let previewIndex = 0
    let clickedItemHasImage = false
    for (let i = 0; i < items.length; i++) {
      if (items[i].filePath !== '') {
        if (i === index) {
          previewIndex = images.length
          clickedItemHasImage = true
        }
        images.push('file://' + items[i].filePath)
        transitionIds.push(this.getPreviewTransitionId(items[i]))
        aspectRatios.push(this.getMediaAspectRatioValue(items[i].aspectRatio))
      }
    }
    if (imageGenerationPagePathStack === null || images.length === 0 ||
      (index >= 0 && index < items.length && !clickedItemHasImage)) {
      return
    }

    const routeParams = new ImageGenerationPreviewRouteParams()
    routeParams.images = images
    routeParams.selectedIndex = previewIndex
    routeParams.transitionIds = transitionIds
    routeParams.aspectRatios = aspectRatios
    routeParams.topSafeAreaVp = this.getTopPadding()
    routeParams.bottomSafeAreaVp = this.px2vp(getAppUiState().bottomAvoidHeight)
    routeParams.onIndexChange = (previewListIndex: number): void => {
      this.syncPreviewSource(transitionIds, previewListIndex)
    }
    routeParams.onBackToSource = (): void => {
      this.previewSourceVisible = true
    }
    routeParams.onPreviewClosed = (): void => {
      this.isPreviewRouteOpen = false
      setTimeout(() => {
        if (!this.isPreviewRouteOpen) {
          this.activePreviewTransitionId = ''
          this.previewSourceVisible = true
        }
      }, 40)
    }

    this.isPreviewRouteOpen = true
    this.previewSourceVisible = true
    this.activePreviewTransitionId = transitionIds[previewIndex]
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
      if (imageGenerationPagePathStack !== null) {
        imageGenerationPagePathStack.pushPath({ name: IMAGE_GENERATION_PREVIEW_ROUTE, param: routeParams }, false)
        this.previewSourceVisible = false
      }
    })
  }

  private syncPreviewSource(transitionIds: string[], previewListIndex: number): void {
    if (previewListIndex >= 0 && previewListIndex < transitionIds.length) {
      this.activePreviewTransitionId = transitionIds[previewListIndex]
      this.previewSourceVisible = false
    }
  }

  private getPreviewTransitionId(item: GeneratedMedia): string {
    if (item.id === '') {
      return ''
    }
    return `image_generation_preview_${item.id}`
  }

  private getMediaAspectRatioValue(aspectRatio: string): number {
    if (aspectRatio === ImageAspectRatio.LANDSCAPE) {
      return 16 / 9
    }
    if (aspectRatio === ImageAspectRatio.PORTRAIT) {
      return 9 / 16
    }
    return 1
  }

  private async saveMedia(media: GeneratedMedia): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      await saveFileImageToAlbum(context, media.filePath, 'IMG')
      showToast(this.getUIContext(), $r('app.string.image_generation_save_success'))
    } catch (error) {
      console.error('ImageGenerationPage', `Save image failed: ${JSON.stringify(error)}`)
      showToast(this.getUIContext(), $r('app.string.image_generation_save_failed'))
    }
  }

  private copyPrompt(media: GeneratedMedia): void {
    try {
      const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, media.prompt)
      pasteboard.getSystemPasteboard().setData(pasteboardData)
      showToast(this.getUIContext(), $r('app.string.image_generation_copy_prompt_success'))
    } catch (error) {
      console.error('ImageGenerationPage', `Copy prompt failed: ${JSON.stringify(error)}`)
    }
  }

  private confirmDelete(media: GeneratedMedia): void {
    this.pendingDeleteId = media.id
    this.showDeleteSheet = true
  }

  private async deletePendingMedia(): Promise<void> {
    const id = this.pendingDeleteId
    this.pendingDeleteId = ''
    this.showDeleteSheet = false
    if (id !== '') {
      await this.viewModel.deleteMedia(id)
    }
  }

  build() {
    Stack() {
      Column() {
        this.Header()
        this.TabBar()

        if (this.currentTabIndex === 0) {
          this.GenerateTab()
        } else {
          this.GalleryTab()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeBackground)

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showSettingsSheet, this.SettingsSheet(), {
          height: SheetSize.MEDIUM,
          dragBar: true,
          showClose: true,
          title: { title: $r('app.string.image_generation_settings') }
        })

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showModelSheet, this.ModelSheet(), {
          height: SheetSize.LARGE,
          dragBar: true,
          showClose: true,
          title: { title: $r('app.string.image_generation_model') }
        })

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showDeleteSheet, this.DeleteConfirmSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false
        })

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showCancelSheet, this.CancelConfirmSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private Header() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
      }
      .type(ButtonType.Circle)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.handleBack()
      })

      Text($r('app.string.image_generation_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(20)
          .fontColor([this.themePrimary])
      }
      .type(ButtonType.Circle)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.viewModel.clearSession()
      })
    }
    .width('100%')
    .height(56 + this.getTopPadding())
    .padding({ left: 12, right: 12, top: this.getTopPadding() })
    .backgroundColor(this.themeBackground)
  }

  @Builder
  private TabBar() {
    Row({ space: 8 }) {
      this.TabButton(0, $r('app.string.image_generation_tab_generate'))
      this.TabButton(1, $r('app.string.image_generation_tab_gallery'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  private TabButton(index: number, label: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Text(label)
        .fontSize(14)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? this.themePrimary : $r('app.color.text_secondary'))
    }
    .height(36)
    .layoutWeight(1)
    .backgroundColor(this.currentTabIndex === index ? getAppUiState().themePrimaryLight : this.themeSurface)
    .onClick(() => {
      this.currentTabIndex = index
    })
  }

  @Builder
  private GenerateTab() {
    Column() {
      if (this.viewModel.errorMessage !== '') {
        Text(this.viewModel.errorMessage)
          .fontSize(13)
          .fontColor($r('app.color.status_error'))
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 6 })
      }

      ImageResultGrid({
        isGenerating: this.viewModel.isGenerating,
        isEditing: this.isEditingMode(),
        items: this.viewModel.currentImages,
        activePreviewTransitionId: this.activePreviewTransitionId,
        previewSourceVisible: this.previewSourceVisible,
        onPreview: (index: number): void => {
          this.openPreview(this.viewModel.currentImages, index)
        },
        onSave: (item: GeneratedMedia): void => {
          this.saveMedia(item)
        },
        onCopyPrompt: (item: GeneratedMedia): void => {
          this.copyPrompt(item)
        },
        onDelete: (item: GeneratedMedia): void => {
          this.confirmDelete(item)
        }
      })

      ImagePromptBar({
        prompt: this.viewModel.prompt,
        isGenerating: this.viewModel.isGenerating,
        isEditing: this.isEditingMode(),
        canGenerate: this.viewModel.canGenerate(),
        selectedModelId: this.viewModel.selectedModelId,
        selectedModelName: this.viewModel.getSelectedModelLabel(),
        selectedProviderId: this.viewModel.selectedProviderId,
        selectedProviderIconType: this.getSelectedProviderIconType(),
        selectedProviderIconPath: this.getSelectedProviderIconPath(),
        selectedProviderTextIcon: this.getSelectedProviderTextIcon(),
        selectedProviderTextIconBgColor: this.getSelectedProviderTextIconBgColor(),
        selectedProviderCustomImagePath: this.getSelectedProviderCustomImagePath(),
        selectedProviderBrandColor: this.getSelectedProviderBrandColor(),
        referenceImages: this.viewModel.referenceImages,
        onPromptChange: (value: string): void => {
          this.viewModel.updatePrompt(value)
        },
        onOpenModelSheet: (): void => {
          this.showModelSheet = true
        },
        onOpenSettings: (): void => {
          this.showSettingsSheet = true
        },
        onPickReferenceImages: (): void => {
          this.pickReferenceImages()
        },
        onGenerate: (): void => {
          this.viewModel.generate()
        },
        onCancel: (): void => {
          this.showCancelSheet = true
        },
        onRemoveReferenceImage: (path: string): void => {
          this.viewModel.removeReferenceImage(path)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private GalleryTab() {
    Column() {
      ImageGalleryGrid({
        items: this.viewModel.galleryItems,
        columns: this.getGalleryColumns(),
        activePreviewTransitionId: this.activePreviewTransitionId,
        previewSourceVisible: this.previewSourceVisible,
        onPreview: (index: number): void => {
          this.openPreview(this.viewModel.galleryItems, index)
        },
        onSave: (item: GeneratedMedia): void => {
          this.saveMedia(item)
        },
        onCopyPrompt: (item: GeneratedMedia): void => {
          this.copyPrompt(item)
        },
        onDelete: (item: GeneratedMedia): void => {
          this.confirmDelete(item)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private SettingsSheet() {
    ImageGenerationSettingsSheet({
      numberOfImages: this.viewModel.numberOfImages,
      selectedAspectRatio: this.viewModel.aspectRatio,
      onNumberChange: (value: number): void => {
        this.viewModel.updateNumberOfImages(value)
      },
      onAspectRatioChange: (value: ImageAspectRatio): void => {
        this.viewModel.updateAspectRatio(value)
      }
    })
  }

  @Builder
  private ModelSheet() {
    ImageGenerationModelSheet({
      providers: this.viewModel.providers,
      isProvidersLoaded: this.viewModel.isProvidersLoaded,
      currentModelId: this.viewModel.selectedModelId,
      currentProviderId: this.viewModel.selectedProviderId,
      onSelectModel: (providerId: string, modelId: string, modelName: string): void => {
        this.viewModel.selectModel(providerId, modelId, modelName)
        this.showModelSheet = false
      }
    })
  }

  @Builder
  private DeleteConfirmSheet() {
    this.ConfirmSheet(
      $r('app.string.image_generation_delete_title'),
      $r('app.string.image_generation_delete_message'),
      $r('app.string.delete'),
      (): void => {
        this.deletePendingMedia()
      },
      (): void => {
        this.showDeleteSheet = false
        this.pendingDeleteId = ''
      }
    )
  }

  @Builder
  private CancelConfirmSheet() {
    this.ConfirmSheet(
      this.isEditingMode() ?
        $r('app.string.image_generation_cancel_edit_title') :
        $r('app.string.image_generation_cancel_title'),
      this.isEditingMode() ?
        $r('app.string.image_generation_cancel_edit_message') :
        $r('app.string.image_generation_cancel_message'),
      this.isEditingMode() ?
        $r('app.string.image_generation_cancel_edit') :
        $r('app.string.image_generation_cancel'),
      (): void => {
        this.showCancelSheet = false
        this.viewModel.cancelGeneration()
      },
      (): void => {
        this.showCancelSheet = false
      }
    )
  }

  @Builder
  private ConfirmSheet(
    title: Resource,
    message: Resource,
    confirmText: Resource,
    onConfirm: () => void,
    onCancel: () => void
  ) {
    Column({ space: 16 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.cancel'))
          .height(44)
          .layoutWeight(1)
          .backgroundColor(this.themeSurface)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            onCancel()
          })

        Button(confirmText)
          .height(44)
          .layoutWeight(1)
          .backgroundColor($r('app.color.status_error'))
          .fontColor(Color.White)
          .onClick(() => {
            onConfirm()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 28 })
  }
}

@Builder
export function ImageGenerationPageBuilder(name: string, param: Object) {
  NavDestination() {
    ImageGenerationPage()
  }
  .hideTitleBar(true)
  .hideBackButton(true)
  .onReady((context: NavDestinationContext) => {
    imageGenerationPagePathStack = context.pathStack
  })
  .onBackPressed((): boolean => {
    if (imageGenerationBackHandler !== null) {
      return imageGenerationBackHandler()
    }
    return true
  })
}
