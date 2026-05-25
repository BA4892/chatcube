import { AttachmentType, MessageAttachment } from '../../models/ChatModels'
import { getAppUiState } from '../../state/AppUiState'
import { AdaptiveImageThumbnail } from '../AdaptiveImageThumbnail'

@ComponentV2
export struct DraftPreviewBubble {
  @Param inputText: string = ''
  @Param pendingAttachments: MessageAttachment[] = []
  private get themeUserBubble(): string {
    return getAppUiState().themeUserBubble
  }
  private get themeUserBubbleText(): string {
    return getAppUiState().themeUserBubbleText
  }
  @Param chatFontSize: number = 15
  @Param previewTimeText: string = ''
  @Event onImageClick: (images: Array<string>, imageIndex: number, sourceIds: Array<string>) => void =
    (_images: Array<string>, _imageIndex: number, _sourceIds: Array<string>): void => {}
  @Event onContentLayoutChange: () => void = (): void => {}
  draftPreviewImageMaxHeight: number = 120
  draftPreviewImageContainerWidth: number = 180
  draftPreviewImageGap: number = 6

  private getDraftImageAttachmentIndices(): number[] {
    const imageIndices: number[] = []
    for (let i = 0; i < this.pendingAttachments.length; i++) {
      if (this.pendingAttachments[i].type === AttachmentType.IMAGE) {
        imageIndices.push(i)
      }
    }
    return imageIndices
  }

  private buildDraftImageGridRows(imageCount: number): number[] {
    const rows: number[] = []
    if (imageCount <= 0) {
      return rows
    }
    const rowCount = Math.ceil(imageCount / 2)
    for (let i = 0; i < rowCount; i++) {
      rows.push(i)
    }
    return rows
  }

  private getAttachmentImageSource(attachment: MessageAttachment): string {
    if (attachment.filePath !== '') {
      return 'file://' + attachment.filePath
    }
    if (attachment.base64Data !== '') {
      return `data:${attachment.mimeType};base64,${attachment.base64Data}`
    }
    return ''
  }

  private getAttachmentImagePreviewId(attachment: MessageAttachment, originalIndex: number): string {
    if (attachment.id !== '') {
      return 'draft_img_' + attachment.id
    }
    if (attachment.filePath !== '') {
      return 'draft_img_' + attachment.filePath
    }
    return `draft_img_${originalIndex}`
  }

  private handleImagePreview(clickedIndex: number): void {
    const imagePaths: Array<string> = []
    const imageSourceIds: Array<string> = []
    let imageIndex = 0
    let clickedImageFound = false

    for (let i = 0; i < this.pendingAttachments.length; i++) {
      const attachment = this.pendingAttachments[i]
      if (attachment.type !== AttachmentType.IMAGE) {
        continue
      }
      const imageSource = this.getAttachmentImageSource(attachment)
      if (imageSource === '') {
        continue
      }
      if (i === clickedIndex) {
        imageIndex = imagePaths.length
        clickedImageFound = true
      }
      imagePaths.push(imageSource)
      imageSourceIds.push(this.getAttachmentImagePreviewId(attachment, i))
    }

    if (imagePaths.length > 0 && clickedImageFound) {
      this.onImageClick(imagePaths, imageIndex, imageSourceIds)
    }
  }

  @Builder
  private DraftPreviewSingleImage(attachment: MessageAttachment, attachmentIndex: number, bottomMargin: number) {
    if (this.getAttachmentImageSource(attachment) !== '') {
      AdaptiveImageThumbnail({
        src: this.getAttachmentImageSource(attachment),
        previewId: this.getAttachmentImagePreviewId(attachment, attachmentIndex),
        maxWidth: this.draftPreviewImageContainerWidth,
        maxHeight: this.draftPreviewImageMaxHeight,
        radius: 12,
        onContentLayoutChange: (): void => {
          this.onContentLayoutChange()
        },
        onPreview: () => {
          this.handleImagePreview(attachmentIndex)
        }
      })
        .margin({ bottom: bottomMargin })
    }
  }

  @Builder
  private DraftPreviewGridImage(attachment: MessageAttachment, attachmentIndex: number) {
    if (this.getAttachmentImageSource(attachment) !== '') {
      AdaptiveImageThumbnail({
        src: this.getAttachmentImageSource(attachment),
        previewId: this.getAttachmentImagePreviewId(attachment, attachmentIndex),
        maxWidth: (this.draftPreviewImageContainerWidth - this.draftPreviewImageGap) / 2,
        maxHeight: this.draftPreviewImageMaxHeight,
        radius: 12,
        onContentLayoutChange: (): void => {
          this.onContentLayoutChange()
        },
        onPreview: () => {
          this.handleImagePreview(attachmentIndex)
        }
      })
    }
  }

  @Builder
  private DraftPreviewImages(draftImageIndices: number[]) {
    if (draftImageIndices.length === 1) {
      this.DraftPreviewSingleImage(this.pendingAttachments[draftImageIndices[0]], draftImageIndices[0],
        this.inputText.trim().length > 0 ? 6 : 0)
    } else if (draftImageIndices.length > 1) {
      Column({ space: this.draftPreviewImageGap }) {
        ForEach(this.buildDraftImageGridRows(draftImageIndices.length), (rowIndex: number) => {
          Row({ space: this.draftPreviewImageGap }) {
            this.DraftPreviewGridImage(this.pendingAttachments[draftImageIndices[rowIndex * 2]],
              draftImageIndices[rowIndex * 2])

            if (rowIndex * 2 + 1 < draftImageIndices.length) {
              this.DraftPreviewGridImage(this.pendingAttachments[draftImageIndices[rowIndex * 2 + 1]],
                draftImageIndices[rowIndex * 2 + 1])
            }
          }
        }, (rowIndex: number) => rowIndex.toString())
      }
      .margin({ bottom: this.inputText.trim().length > 0 ? 6 : 0 })
    }
  }

  build() {
    Column() {
      Row() {
        Blank()

        Column() {
          if (this.pendingAttachments.length > 0) {
            this.DraftPreviewImages(this.getDraftImageAttachmentIndices())
          }

          if (this.inputText.trim().length > 0) {
            Text(this.inputText.trim())
              .fontSize(this.chatFontSize)
              .fontColor(this.themeUserBubbleText)
              .lineHeight(this.chatFontSize + 7)
          } else {
            Text($r('app.string.input_placeholder'))
              .fontSize(this.chatFontSize)
              .fontColor(this.themeUserBubbleText)
              .opacity(0.45)
              .lineHeight(this.chatFontSize + 7)
          }
        }
        .padding(this.pendingAttachments.length > 0 ?
          {
            left: 8,
            right: 8,
            top: 8,
            bottom: 8
          } :
          {
            left: 14,
            right: 14,
            top: 10,
            bottom: 10
          })
        .backgroundColor(this.themeUserBubble)
        .borderRadius({
          topLeft: 20,
          topRight: 20,
          bottomLeft: 20,
          bottomRight: 6
        })
        .clip(true)
        .constraintSize({ maxWidth: '75%' })
        .opacity(0.55)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.End)
  }
}

