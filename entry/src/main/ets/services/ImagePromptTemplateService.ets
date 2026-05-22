import { ImagePromptTemplate } from '../models/ImagePromptTemplateModels'
import { getHttpService, HttpService } from './HttpService'
import { getPreferencesService, PreferencesService, PreferenceKeys } from './PreferencesService'

const BUILTIN_TEMPLATE_VERSION = 1
const REMOTE_TEMPLATE_VERSION_OFFSET = 1000
export const IMAGE_PROMPT_TEMPLATES_REMOTE_URL =
  'https://beta.04160518.xyz/chatbox/image-prompt-templates.json'

interface ImagePromptTemplateJsonData {
  id?: string
  title?: string
  prompt?: string
  builtin?: boolean
  order?: number
  createdAt?: number
  updatedAt?: number
}

interface ImagePromptTemplateRemotePayload {
  version: number
  templates: ImagePromptTemplateJsonData[]
}

class ImagePromptTemplateMergeResult {
  templates: ImagePromptTemplate[] = []
  changed: boolean = false
}

class ImagePromptTemplateRemotePayloadData {
  version: number = BUILTIN_TEMPLATE_VERSION
  templates: ImagePromptTemplateJsonData[] = []
}

export class ImagePromptTemplateService {
  private static instance: ImagePromptTemplateService | null = null
  private preferencesService: PreferencesService = getPreferencesService()
  private httpService: HttpService = getHttpService()

  static getInstance(): ImagePromptTemplateService {
    if (ImagePromptTemplateService.instance === null) {
      ImagePromptTemplateService.instance = new ImagePromptTemplateService()
    }
    return ImagePromptTemplateService.instance
  }

  async listTemplates(): Promise<ImagePromptTemplate[]> {
    const templates = await this.loadTemplates()
    return this.sortTemplates(templates)
  }

  async saveTemplate(template: ImagePromptTemplate): Promise<ImagePromptTemplate[]> {
    const templates = await this.loadTemplates()
    const now = Date.now()
    const normalized = this.cloneTemplate(template)
    normalized.title = normalized.title.trim()
    normalized.prompt = normalized.prompt.trim()
    if (normalized.id === '') {
      normalized.id = `custom_${now}_${Math.floor(Math.random() * 10000)}`
      normalized.builtin = false
      normalized.createdAt = now
      normalized.order = this.getNextOrder(templates)
    }
    normalized.updatedAt = now
    const index = this.indexOfTemplate(templates, normalized.id)
    if (index >= 0) {
      const previous = templates[index]
      normalized.builtin = previous.builtin
      normalized.createdAt = previous.createdAt
      normalized.order = previous.order
      templates[index] = normalized
    } else {
      templates.push(normalized)
    }
    return await this.persistTemplates(templates)
  }

  async deleteTemplate(id: string): Promise<ImagePromptTemplate[]> {
    const templates = await this.loadTemplates()
    const next: ImagePromptTemplate[] = []
    for (let i = 0; i < templates.length; i++) {
      if (templates[i].id === id && !templates[i].builtin) {
        continue
      }
      next.push(templates[i])
    }
    return await this.persistTemplates(next)
  }

  async resetBuiltins(): Promise<ImagePromptTemplate[]> {
    const templates = await this.loadTemplates()
    const customTemplates: ImagePromptTemplate[] = []
    for (let i = 0; i < templates.length; i++) {
      if (!templates[i].builtin) {
        customTemplates.push(templates[i])
      }
    }
    const next = this.getBuiltinTemplates()
    for (let i = 0; i < customTemplates.length; i++) {
      next.push(customTemplates[i])
    }
    return await this.persistTemplates(next, BUILTIN_TEMPLATE_VERSION)
  }

  async syncRemoteBuiltins(): Promise<ImagePromptTemplate[]> {
    const response = await this.httpService.get(IMAGE_PROMPT_TEMPLATES_REMOTE_URL)
    if (!response.success) {
      throw new Error(response.errorMessage !== '' ? response.errorMessage : `HTTP ${response.statusCode}`)
    }
    const payload = this.parseRemotePayload(response.data)
    const remoteBuiltins = this.normalizeRemoteBuiltins(payload.templates, payload.version)
    if (remoteBuiltins.length === 0) {
      throw new Error('Remote prompt template list is empty')
    }
    const templates = await this.loadTemplates()
    const next: ImagePromptTemplate[] = []
    for (let i = 0; i < templates.length; i++) {
      if (!templates[i].builtin) {
        next.push(templates[i])
      }
    }
    for (let i = 0; i < remoteBuiltins.length; i++) {
      next.push(remoteBuiltins[i])
    }
    return await this.persistTemplates(next, REMOTE_TEMPLATE_VERSION_OFFSET + payload.version)
  }

  private async loadTemplates(): Promise<ImagePromptTemplate[]> {
    const raw = await this.preferencesService.getString(PreferenceKeys.IMAGE_PROMPT_TEMPLATES_JSON, '')
    const savedVersion = await this.preferencesService.getNumber(PreferenceKeys.IMAGE_PROMPT_TEMPLATES_VERSION, 0)
    const parsed = this.parseTemplates(raw)
    if (savedVersion >= REMOTE_TEMPLATE_VERSION_OFFSET) {
      if (this.hasBuiltinTemplate(parsed)) {
        return this.sortTemplates(parsed)
      }
      const fallback = this.mergeBuiltins(this.getCustomTemplates(parsed), 0)
      return await this.persistTemplates(fallback.templates, BUILTIN_TEMPLATE_VERSION)
    }
    if (raw !== '' && parsed.length === 0) {
      const fallback = this.mergeBuiltins([], 0)
      return await this.persistTemplates(fallback.templates, BUILTIN_TEMPLATE_VERSION)
    }
    const merged = this.mergeBuiltins(parsed, savedVersion)
    if (raw === '' || savedVersion < BUILTIN_TEMPLATE_VERSION || merged.changed) {
      return await this.persistTemplates(merged.templates, BUILTIN_TEMPLATE_VERSION)
    }
    return merged.templates
  }

  private hasBuiltinTemplate(templates: ImagePromptTemplate[]): boolean {
    for (let i = 0; i < templates.length; i++) {
      if (templates[i].builtin) {
        return true
      }
    }
    return false
  }

  private getCustomTemplates(templates: ImagePromptTemplate[]): ImagePromptTemplate[] {
    const customTemplates: ImagePromptTemplate[] = []
    for (let i = 0; i < templates.length; i++) {
      if (!templates[i].builtin) {
        customTemplates.push(templates[i])
      }
    }
    return customTemplates
  }

  private parseTemplates(raw: string): ImagePromptTemplate[] {
    if (raw.trim() === '') {
      return []
    }
    try {
      const parsed = JSON.parse(raw) as Object
      if (!Array.isArray(parsed)) {
        return []
      }
      const templates: ImagePromptTemplate[] = []
      const array = parsed as Object[]
      for (let i = 0; i < array.length; i++) {
        if (array[i] === null || array[i] === undefined || typeof array[i] !== 'object' || Array.isArray(array[i])) {
          continue
        }
        const template = this.fromJson(array[i] as ImagePromptTemplateJsonData, false)
        if (template.id !== '' && template.prompt.trim() !== '') {
          templates.push(template)
        }
      }
      return templates
    } catch (error) {
      console.error('ImagePromptTemplateService', `Parse templates failed: ${JSON.stringify(error)}`)
      return []
    }
  }

  private parseRemotePayload(raw: string): ImagePromptTemplateRemotePayload {
    const parsed = JSON.parse(raw) as Object
    const payload = new ImagePromptTemplateRemotePayloadData()
    if (Array.isArray(parsed)) {
      payload.version = BUILTIN_TEMPLATE_VERSION
      payload.templates = parsed as ImagePromptTemplateJsonData[]
      return payload
    }
    const record = parsed as Record<string, Object>
    payload.version = typeof record.version === 'number' ? record.version as number : BUILTIN_TEMPLATE_VERSION
    payload.templates = Array.isArray(record.templates) ? record.templates as ImagePromptTemplateJsonData[] : []
    return payload
  }

  private normalizeRemoteBuiltins(
    data: ImagePromptTemplateJsonData[],
    version: number
  ): ImagePromptTemplate[] {
    const templates: ImagePromptTemplate[] = []
    const timestamp = Date.now()
    const versionValue = version > 0 ? version : BUILTIN_TEMPLATE_VERSION
    for (let i = 0; i < data.length; i++) {
      const template = this.fromJson(data[i], true)
      if (template.prompt.trim() === '') {
        continue
      }
      if (template.id === '') {
        template.id = `remote_${versionValue}_${i}`
      }
      template.builtin = true
      template.order = template.order > 0 ? template.order : (i + 1) * 10
      template.createdAt = template.createdAt > 0 ? template.createdAt : timestamp + template.order
      template.updatedAt = timestamp
      templates.push(template)
    }
    return this.sortTemplates(templates)
  }

  private mergeBuiltins(
    templates: ImagePromptTemplate[],
    savedVersion: number
  ): ImagePromptTemplateMergeResult {
    let changed = false
    const next: ImagePromptTemplate[] = templates.slice()
    const builtins = this.getBuiltinTemplates()
    for (let i = 0; i < builtins.length; i++) {
      const builtin = builtins[i]
      const index = this.indexOfTemplate(next, builtin.id)
      if (index < 0) {
        next.push(builtin)
        changed = true
        continue
      }
      if (savedVersion < BUILTIN_TEMPLATE_VERSION) {
        next[index] = builtin
        changed = true
      }
    }
    const result = new ImagePromptTemplateMergeResult()
    result.templates = this.sortTemplates(next)
    result.changed = changed
    return result
  }

  private async persistTemplates(
    templates: ImagePromptTemplate[],
    version: number = BUILTIN_TEMPLATE_VERSION
  ): Promise<ImagePromptTemplate[]> {
    const sorted = this.sortTemplates(templates)
    await this.preferencesService.setString(PreferenceKeys.IMAGE_PROMPT_TEMPLATES_JSON, JSON.stringify(sorted))
    await this.preferencesService.setNumber(PreferenceKeys.IMAGE_PROMPT_TEMPLATES_VERSION, version)
    return sorted
  }

  private fromJson(data: ImagePromptTemplateJsonData, forceBuiltin: boolean): ImagePromptTemplate {
    const template = new ImagePromptTemplate()
    template.id = typeof data.id === 'string' ? data.id : ''
    template.title = typeof data.title === 'string' ? data.title : ''
    template.prompt = typeof data.prompt === 'string' ? data.prompt : ''
    template.builtin = forceBuiltin ? true : (typeof data.builtin === 'boolean' ? data.builtin : false)
    template.order = typeof data.order === 'number' ? data.order : 0
    template.createdAt = typeof data.createdAt === 'number' ? data.createdAt : Date.now()
    template.updatedAt = typeof data.updatedAt === 'number' ? data.updatedAt : template.createdAt
    return template
  }

  private cloneTemplate(source: ImagePromptTemplate): ImagePromptTemplate {
    const template = new ImagePromptTemplate()
    template.id = source.id
    template.title = source.title
    template.prompt = source.prompt
    template.builtin = source.builtin
    template.order = source.order
    template.createdAt = source.createdAt
    template.updatedAt = source.updatedAt
    return template
  }

  private sortTemplates(templates: ImagePromptTemplate[]): ImagePromptTemplate[] {
    return templates.slice().sort((left: ImagePromptTemplate, right: ImagePromptTemplate): number => {
      if (left.order !== right.order) {
        return left.order - right.order
      }
      return left.createdAt - right.createdAt
    })
  }

  private indexOfTemplate(templates: ImagePromptTemplate[], id: string): number {
    for (let i = 0; i < templates.length; i++) {
      if (templates[i].id === id) {
        return i
      }
    }
    return -1
  }

  private getNextOrder(templates: ImagePromptTemplate[]): number {
    let maxOrder = 0
    for (let i = 0; i < templates.length; i++) {
      if (templates[i].order > maxOrder) {
        maxOrder = templates[i].order
      }
    }
    return maxOrder + 10
  }

  private getBuiltinTemplates(): ImagePromptTemplate[] {
    const now = 1700000000000
    const templates: ImagePromptTemplate[] = []
    templates.push(this.createBuiltin(
      'builtin_cyberpunk_street',
      '赛博朋克街道',
      '夜晚霓虹下的赛博朋克城市街道,湿漉漉地面反射光斑,电影感构图',
      10,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_watercolor_cabin',
      '水彩山间小屋',
      '水彩风格的山间小屋,清晨薄雾,柔和光线',
      20,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_space_dog',
      '宇航员柴犬',
      '可爱柴犬戴着宇航员头盔,3D 立体卡通风格,星空背景',
      30,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_minimal_coffee',
      '极简咖啡杯',
      '极简线稿风格的咖啡杯特写,纯白背景,工业设计感',
      40,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_steampunk_butterfly',
      '机械蝴蝶微距',
      '蒸汽朋克机械蝴蝶,精细金属齿轮,微距镜头',
      50,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_product_watch',
      '高级手表广告',
      '黑色陶瓷智能手表产品摄影,悬浮在深灰背景前,边缘冷光,高端广告质感',
      60,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_architecture_library',
      '未来图书馆',
      '未来主义公共图书馆室内空间,巨大的弧形书架,自然天光,安静通透的建筑摄影',
      70,
      now
    ))
    templates.push(this.createBuiltin(
      'builtin_character_ranger',
      '荒野探索者',
      '原创幻想角色设定图,荒野探索者,多层布料与金属护具,全身站姿,干净浅色背景',
      80,
      now
    ))
    return templates
  }

  private createBuiltin(
    id: string,
    title: string,
    prompt: string,
    order: number,
    timestamp: number
  ): ImagePromptTemplate {
    const template = new ImagePromptTemplate()
    template.id = id
    template.title = title
    template.prompt = prompt
    template.builtin = true
    template.order = order
    template.createdAt = timestamp + order
    template.updatedAt = timestamp + order
    return template
  }
}

export function getImagePromptTemplateService(): ImagePromptTemplateService {
  return ImagePromptTemplateService.getInstance()
}
