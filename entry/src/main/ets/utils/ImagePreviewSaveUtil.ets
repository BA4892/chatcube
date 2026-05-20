import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { http } from '@kit.NetworkKit'

export async function savePreviewImageToAlbum(context: common.UIAbilityContext, imageUri: string): Promise<void> {
  if (imageUri.startsWith('data:')) {
    await saveFromBase64(context, imageUri)
    return
  }
  if (imageUri.startsWith('http://') || imageUri.startsWith('https://')) {
    await saveFromRemoteUri(context, imageUri)
    return
  }
  await saveFromFileUri(context, imageUri)
}

async function saveFromFileUri(context: common.UIAbilityContext, imageUri: string): Promise<void> {
  let srcFile: fileIo.File | null = null
  let desFile: fileIo.File | null = null
  try {
    const srcPath = resolveLocalFilePath(imageUri)
    if (srcPath === '') {
      throw new Error('Image path is empty')
    }
    const srcUri = fileUri.getUriFromPath(srcPath)
    const ext = getExtensionFromUri(srcPath)
    const config: photoAccessHelper.PhotoCreationConfig = {
      title: `IMG_${Date.now()}`,
      fileNameExtension: ext,
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    }

    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    const desFileUris = await phAccessHelper.showAssetsCreationDialog([srcUri], [config])
    if (desFileUris.length === 0) {
      throw new Error('No target file uri selected')
    }

    srcFile = fileIo.openSync(srcPath, fileIo.OpenMode.READ_ONLY)
    desFile = fileIo.openSync(desFileUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    await fileIo.copyFile(srcFile.fd, desFile.fd)
  } catch (error) {
    throw new Error(`Save from file uri failed: ${formatSaveError(error)}`)
  } finally {
    closeFileQuietly(srcFile)
    closeFileQuietly(desFile)
  }
}

async function saveFromRemoteUri(context: common.UIAbilityContext, imageUri: string): Promise<void> {
  let tempFilePath = ''
  try {
    tempFilePath = await downloadRemoteImageToTempPath(context, imageUri)
    await saveFromFileUri(context, fileUri.getUriFromPath(tempFilePath))
  } catch (error) {
    throw new Error(`Save from remote uri failed: ${formatSaveError(error)}`)
  } finally {
    unlinkQuietly(tempFilePath)
  }
}

async function downloadRemoteImageToTempPath(context: common.UIAbilityContext, imageUri: string): Promise<string> {
  const httpRequest = http.createHttp()
  let tempFile: fileIo.File | null = null
  let tempFilePath = ''
  try {
    const response = await httpRequest.request(imageUri, {
      method: http.RequestMethod.GET,
      connectTimeout: 15000,
      readTimeout: 60000,
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    })
    if (response.responseCode !== 200) {
      throw new Error(`HTTP ${response.responseCode}`)
    }

    const imageBuffer = response.result as ArrayBuffer
    if (imageBuffer.byteLength <= 0) {
      throw new Error('Empty image data')
    }

    const contentType = response.header?.['content-type'] as string | undefined
    const ext = getExtensionForRemoteImage(imageUri, contentType)
    tempFilePath = `${context.cacheDir}/temp_save_${Date.now()}.${ext}`
    tempFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    fileIo.writeSync(tempFile.fd, imageBuffer)
    return tempFilePath
  } catch (error) {
    unlinkQuietly(tempFilePath)
    throw new Error(`Download remote image failed: ${formatSaveError(error)}`)
  } finally {
    closeFileQuietly(tempFile)
    httpRequest.destroy()
  }
}

async function saveFromBase64(context: common.UIAbilityContext, dataUri: string): Promise<void> {
  const commaIndex = dataUri.indexOf(',')
  if (commaIndex < 0) {
    throw new Error('Invalid data uri')
  }

  const base64Data = dataUri.substring(commaIndex + 1)
  const mimeSection = dataUri.substring(0, commaIndex)
  const ext = getExtensionFromMimeSection(mimeSection)
  const decodedBuffer = buffer.from(base64Data, 'base64')
  const tempFilePath = `${context.cacheDir}/temp_save_${Date.now()}.${ext}`
  let tempFile: fileIo.File | null = null

  try {
    tempFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    fileIo.writeSync(tempFile.fd, decodedBuffer.buffer)
    closeFileQuietly(tempFile)
    tempFile = null
    await saveFromFileUri(context, fileUri.getUriFromPath(tempFilePath))
  } catch (error) {
    throw new Error(`Save from base64 failed: ${formatSaveError(error)}`)
  } finally {
    closeFileQuietly(tempFile)
    unlinkQuietly(tempFilePath)
  }
}

function getExtensionFromMimeSection(mimeSection: string): string {
  if (mimeSection.includes('jpeg') || mimeSection.includes('jpg')) {
    return 'jpg'
  }
  if (mimeSection.includes('gif')) {
    return 'gif'
  }
  if (mimeSection.includes('webp')) {
    return 'webp'
  }
  return 'png'
}

function getExtensionFromUri(uri: string): string {
  let cleanUri = uri
  const queryIndex = cleanUri.indexOf('?')
  if (queryIndex >= 0) {
    cleanUri = cleanUri.substring(0, queryIndex)
  }
  const fragmentIndex = cleanUri.indexOf('#')
  if (fragmentIndex >= 0) {
    cleanUri = cleanUri.substring(0, fragmentIndex)
  }
  const dotIndex = cleanUri.lastIndexOf('.')
  if (dotIndex >= 0) {
    const ext = cleanUri.substring(dotIndex + 1).toLowerCase()
    return ext === 'jpeg' ? 'jpg' : ext
  }
  return 'jpg'
}

function getExtensionForRemoteImage(uri: string, contentType?: string): string {
  if (contentType !== undefined && contentType !== '') {
    const mimeType = contentType.split(';')[0].trim().toLowerCase()
    if (mimeType === 'image/jpeg' || mimeType === 'image/jpg') {
      return 'jpg'
    }
    if (mimeType === 'image/png') {
      return 'png'
    }
    if (mimeType === 'image/gif') {
      return 'gif'
    }
    if (mimeType === 'image/webp') {
      return 'webp'
    }
    if (mimeType === 'image/bmp') {
      return 'bmp'
    }
  }
  return getExtensionFromUri(uri)
}

function resolveLocalFilePath(uri: string): string {
  let cleanUri = uri.trim()
  const queryIndex = cleanUri.indexOf('?')
  if (queryIndex >= 0) {
    cleanUri = cleanUri.substring(0, queryIndex)
  }
  const fragmentIndex = cleanUri.indexOf('#')
  if (fragmentIndex >= 0) {
    cleanUri = cleanUri.substring(0, fragmentIndex)
  }
  if (!cleanUri.toLowerCase().startsWith('file://')) {
    return cleanUri
  }
  try {
    return new fileUri.FileUri(cleanUri).path
  } catch (_error) {
    return cleanUri.substring(7)
  }
}

function formatSaveError(error: Object): string {
  if (error instanceof Error) {
    return error.message
  }
  return JSON.stringify(error)
}

function closeFileQuietly(file: fileIo.File | null): void {
  if (file === null) {
    return
  }
  try {
    fileIo.closeSync(file)
  } catch (_error) {
  }
}

function unlinkQuietly(path: string): void {
  if (path === '') {
    return
  }
  try {
    fileIo.unlinkSync(path)
  } catch (_error) {
  }
}
