export enum ImageAspectRatio {
  SQUARE = 'square',
  LANDSCAPE = 'landscape',
  PORTRAIT = 'portrait'
}

export enum GeneratedMediaType {
  IMAGE_GENERATION = 'image_generation',
  IMAGE_EDIT = 'image_edit'
}

export class ImageGenerationOptions {
  prompt: string = ''
  numberOfImages: number = 1
  aspectRatio: ImageAspectRatio = ImageAspectRatio.SQUARE
}

export class ImageGenerationRequest {
  providerId: string = ''
  modelId: string = ''
  prompt: string = ''
  numberOfImages: number = 1
  aspectRatio: ImageAspectRatio = ImageAspectRatio.SQUARE
  referenceImagePaths: string[] = []
}

export class ImageGenerationItem {
  base64Data: string = ''
  mimeType: string = 'image/png'
}

export class ImageGenerationResult {
  items: ImageGenerationItem[] = []
}

@ObservedV2
export class GeneratedMedia {
  @Trace id: string = ''
  @Trace type: string = GeneratedMediaType.IMAGE_GENERATION
  @Trace prompt: string = ''
  @Trace providerId: string = ''
  @Trace providerName: string = ''
  @Trace modelId: string = ''
  @Trace modelName: string = ''
  @Trace filePath: string = ''
  @Trace mimeType: string = 'image/png'
  @Trace aspectRatio: string = ImageAspectRatio.SQUARE
  @Trace sourcePathsJson: string = ''
  @Trace createdAt: number = 0
}
