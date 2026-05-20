import { GeneratedMedia } from '../models/ImageGenerationModels'
import { DatabaseService } from './DatabaseService'

export class GeneratedMediaRepository {
  private static instance: GeneratedMediaRepository | null = null
  private databaseService: DatabaseService = DatabaseService.getInstance()

  static getInstance(): GeneratedMediaRepository {
    if (GeneratedMediaRepository.instance === null) {
      GeneratedMediaRepository.instance = new GeneratedMediaRepository()
    }
    return GeneratedMediaRepository.instance
  }

  async insert(media: GeneratedMedia): Promise<void> {
    await this.databaseService.insertGeneratedMedia(media)
  }

  async listRecent(limit: number = 200): Promise<GeneratedMedia[]> {
    return await this.databaseService.getGeneratedMediaList(limit)
  }

  async delete(id: string): Promise<void> {
    await this.databaseService.deleteGeneratedMedia(id)
  }
}

export function getGeneratedMediaRepository(): GeneratedMediaRepository {
  return GeneratedMediaRepository.getInstance()
}
