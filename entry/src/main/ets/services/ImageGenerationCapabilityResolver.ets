import { ApiStyle, ModelInfo, ModelProvider } from '../models/ChatModels'
import {
  ImageAspectRatio,
  ImageGenerationApiRoute,
  ImageGenerationModeration,
  ImageGenerationOutputFormat,
  ImageGenerationQuality
} from '../models/ImageGenerationModels'

export class ImageGenerationRouteCapabilities {
  route: ImageGenerationApiRoute = ImageGenerationApiRoute.UNKNOWN
  supportsQuality: boolean = false
  supportsOutputFormat: boolean = false
  supportsOutputCompression: boolean = false
  supportsModeration: boolean = false
  supportsCustomSize: boolean = false
  supportsMultipleReferences: boolean = true
  maxReferenceImages: number = 4
}

export class ImageGenerationRequestOptionsSnapshot {
  route: string = ''
  size: string = ''
  quality: string = ''
  outputFormat: string = ''
  outputCompression: number = -1
  moderation: string = ''
}

export class ImageGenerationActualOptionsSnapshot {
  size: string = ''
  quality: string = ''
  outputFormat: string = ''
  outputCompression: number = -1
  moderation: string = ''
}

export class ImageGenerationCapabilityResolver {
  static resolve(provider: ModelProvider | null, model: ModelInfo | null): ImageGenerationRouteCapabilities {
    const capabilities = new ImageGenerationRouteCapabilities()
    if (provider === null || model === null) {
      return capabilities
    }

    if (provider.apiStyle === ApiStyle.GOOGLE) {
      capabilities.route = ImageGenerationCapabilityResolver.isGoogleImagenModel(model.id)
        ? ImageGenerationApiRoute.GOOGLE_IMAGEN
        : ImageGenerationApiRoute.GOOGLE_GEMINI_IMAGE
      capabilities.supportsMultipleReferences = capabilities.route !== ImageGenerationApiRoute.GOOGLE_IMAGEN
      capabilities.maxReferenceImages = capabilities.supportsMultipleReferences ? 4 : 0
      return capabilities
    }

    if (ImageGenerationCapabilityResolver.isXAIProvider(provider)) {
      capabilities.route = ImageGenerationApiRoute.XAI_GROK_IMAGE
      capabilities.supportsMultipleReferences = false
      capabilities.maxReferenceImages = 1
      return capabilities
    }

    if (provider.apiStyle === ApiStyle.OPENAI) {
      if (ImageGenerationCapabilityResolver.isOpenAIGptImageModel(model.id)) {
        capabilities.route = ImageGenerationApiRoute.OPENAI_GPT_IMAGE
        capabilities.supportsQuality = true
        capabilities.supportsOutputFormat = true
        capabilities.supportsOutputCompression = true
        capabilities.supportsModeration = true
        capabilities.supportsCustomSize = true
        capabilities.maxReferenceImages = 4
      } else {
        capabilities.route = ImageGenerationApiRoute.OPENAI_LEGACY_IMAGE
        capabilities.maxReferenceImages = 4
      }
    }
    return capabilities
  }

  static isOpenAIGptImageRoute(route: ImageGenerationApiRoute): boolean {
    return route === ImageGenerationApiRoute.OPENAI_GPT_IMAGE
  }

  static normalizeQuality(value: ImageGenerationQuality, capabilities: ImageGenerationRouteCapabilities): ImageGenerationQuality {
    if (!capabilities.supportsQuality) {
      return ImageGenerationQuality.AUTO
    }
    if (value === ImageGenerationQuality.LOW || value === ImageGenerationQuality.MEDIUM || value === ImageGenerationQuality.HIGH) {
      return value
    }
    return ImageGenerationQuality.AUTO
  }

  static normalizeOutputFormat(
    value: ImageGenerationOutputFormat,
    capabilities: ImageGenerationRouteCapabilities
  ): ImageGenerationOutputFormat {
    if (!capabilities.supportsOutputFormat) {
      return ImageGenerationOutputFormat.PNG
    }
    if (value === ImageGenerationOutputFormat.JPEG || value === ImageGenerationOutputFormat.WEBP) {
      return value
    }
    return ImageGenerationOutputFormat.PNG
  }

  static normalizeModeration(
    _value: ImageGenerationModeration,
    capabilities: ImageGenerationRouteCapabilities
  ): ImageGenerationModeration {
    if (!capabilities.supportsModeration) {
      return ImageGenerationModeration.AUTO
    }
    return ImageGenerationModeration.LOW
  }

  static normalizeOutputCompression(
    value: number,
    outputFormat: ImageGenerationOutputFormat,
    capabilities: ImageGenerationRouteCapabilities
  ): number {
    if (!capabilities.supportsOutputCompression || outputFormat === ImageGenerationOutputFormat.PNG) {
      return -1
    }
    if (value < 0) {
      return -1
    }
    if (value > 100) {
      return 100
    }
    return Math.floor(value)
  }

  static getOpenAIImageSize(aspectRatio: ImageAspectRatio): string {
    if (aspectRatio === ImageAspectRatio.LANDSCAPE) {
      return '1536x1024'
    }
    if (aspectRatio === ImageAspectRatio.PORTRAIT) {
      return '1024x1536'
    }
    return '1024x1024'
  }

  static buildRequestOptionsSnapshot(
    route: ImageGenerationApiRoute,
    size: string,
    quality: ImageGenerationQuality,
    outputFormat: ImageGenerationOutputFormat,
    outputCompression: number,
    moderation: ImageGenerationModeration
  ): ImageGenerationRequestOptionsSnapshot {
    const snapshot = new ImageGenerationRequestOptionsSnapshot()
    snapshot.route = route
    snapshot.size = size
    if (route === ImageGenerationApiRoute.OPENAI_GPT_IMAGE) {
      snapshot.quality = quality
      snapshot.outputFormat = outputFormat
      snapshot.outputCompression = outputCompression
      snapshot.moderation = moderation
    }
    return snapshot
  }

  private static isOpenAIGptImageModel(modelId: string): boolean {
    const normalized = modelId.trim().toLowerCase()
    return normalized.includes('gpt-image')
  }

  private static isGoogleImagenModel(modelId: string): boolean {
    return modelId.toLowerCase().includes('imagen')
  }

  private static isXAIProvider(provider: ModelProvider): boolean {
    const id = provider.id.toLowerCase()
    const name = provider.name.toLowerCase()
    const baseUrl = provider.baseUrl.toLowerCase()
    return id.includes('grok') || id.includes('xai') ||
      name.includes('grok') || name.includes('xai') ||
      baseUrl.includes('api.x.ai')
  }
}
