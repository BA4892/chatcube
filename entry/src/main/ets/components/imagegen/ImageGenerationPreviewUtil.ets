import { DefaultMediaModel, DefaultMediaType } from '@lyb/media-preview'
import { GeneratedMedia } from '../../models/ImageGenerationModels'

const IMAGE_GENERATION_PREVIEW_ID_PREFIX = 'image_generation_preview_'

export function hasGeneratedMediaImage(item: GeneratedMedia): boolean {
  return item.filePath !== ''
}

export function getImageGenerationPreviewId(item: GeneratedMedia): string {
  if (item.id !== '') {
    return `${IMAGE_GENERATION_PREVIEW_ID_PREFIX}${item.id}`
  }
  return `${IMAGE_GENERATION_PREVIEW_ID_PREFIX}${item.filePath}`
}

export function getImageGenerationPreviewFallbackId(index: number): string {
  return `${IMAGE_GENERATION_PREVIEW_ID_PREFIX}${index}`
}

export function createImageGenerationPreviewModel(item: GeneratedMedia): DefaultMediaModel {
  const imageUri = 'file://' + item.filePath
  return new DefaultMediaModel(imageUri, imageUri, DefaultMediaType.IMAGE)
}
