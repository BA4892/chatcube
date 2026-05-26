export class AIGeneratedImageFileResult {
  attachmentId: string
  fileName: string
  filePath: string
  mimeType: string
  size: number
  itemId: string
  outputIndex: number

  constructor(
    attachmentId: string,
    fileName: string,
    filePath: string,
    mimeType: string,
    size: number,
    itemId: string = '',
    outputIndex: number = -1
  ) {
    this.attachmentId = attachmentId
    this.fileName = fileName
    this.filePath = filePath
    this.mimeType = mimeType
    this.size = size
    this.itemId = itemId
    this.outputIndex = outputIndex
  }
}

export interface AIGeneratedImageFileSink {
  appendBase64Chunk(chunk: string): void
  complete(itemId: string, outputIndex: number): AIGeneratedImageFileResult
  abort(): void
}
