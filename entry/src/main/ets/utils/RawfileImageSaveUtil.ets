import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

export async function saveRawfileImageToAlbum(
  context: common.UIAbilityContext,
  rawFileName: string,
  titlePrefix: string
): Promise<void> {
  const rawFileData = readRawFileContent(context, rawFileName)
  const extension = rawFileName.toLowerCase().endsWith('.png') ? 'png' : 'jpg'
  const tempPath = `${context.cacheDir}/${titlePrefix}_${Date.now()}.${extension}`
  writeBytesToFile(tempPath, rawFileData)

  try {
    const tempUriStr = resolveFileUri(tempPath)
    const config: photoAccessHelper.PhotoCreationConfig = {
      title: `${titlePrefix}_${Date.now()}`,
      fileNameExtension: extension,
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    }
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    const desFileUris = await phAccessHelper.showAssetsCreationDialog([tempUriStr], [config])
    if (desFileUris.length === 0) {
      throw new Error('User cancelled save')
    }
    await copyFileToUri(tempPath, desFileUris[0])
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to save rawfile image: ${JSON.stringify(error)}`)
    throw new Error(`Failed to save rawfile image: ${JSON.stringify(error)}`)
  } finally {
    try {
      fileIo.unlinkSync(tempPath)
    } catch (_) {
      // ignore cleanup error
    }
  }
}

export async function saveFileImageToAlbum(
  context: common.UIAbilityContext,
  imagePath: string,
  titlePrefix: string
): Promise<void> {
  const localPath = resolveLocalFilePath(imagePath)
  const srcUri = resolveFileUri(localPath)
  const extension = resolveImageExtension(localPath)
  const config: photoAccessHelper.PhotoCreationConfig = {
    title: `${titlePrefix}_${Date.now()}`,
    fileNameExtension: extension,
    photoType: photoAccessHelper.PhotoType.IMAGE,
    subtype: photoAccessHelper.PhotoSubtype.DEFAULT
  }
  const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
  try {
    const desFileUris = await phAccessHelper.showAssetsCreationDialog([srcUri], [config])
    if (desFileUris.length === 0) {
      throw new Error('User cancelled save')
    }
    await copyFileToUri(localPath, desFileUris[0])
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to save file image: ${JSON.stringify(error)}`)
    throw new Error(`Failed to save file image: ${JSON.stringify(error)}`)
  }
}

function readRawFileContent(context: common.UIAbilityContext, rawFileName: string): Uint8Array {
  try {
    return context.resourceManager.getRawFileContentSync(rawFileName)
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to read rawfile image: ${JSON.stringify(error)}`)
    throw new Error(`Failed to read rawfile image: ${JSON.stringify(error)}`)
  }
}

function resolveFileUri(path: string): string {
  try {
    return fileUri.getUriFromPath(path)
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to resolve file uri: ${JSON.stringify(error)}`)
    throw new Error(`Failed to resolve file uri: ${JSON.stringify(error)}`)
  }
}

function writeBytesToFile(path: string, bytes: Uint8Array): void {
  let file: fileIo.File | null = null
  try {
    file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    fileIo.writeSync(file.fd, bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength))
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to write temp image: ${JSON.stringify(error)}`)
    throw new Error(`Failed to write temp image: ${JSON.stringify(error)}`)
  } finally {
    closeFileQuietly(file)
  }
}

async function copyFileToUri(sourcePath: string, destinationUri: string): Promise<void> {
  let srcFile: fileIo.File | null = null
  let desFile: fileIo.File | null = null
  try {
    srcFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY)
    desFile = fileIo.openSync(destinationUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    await fileIo.copyFile(srcFile.fd, desFile.fd)
  } catch (error) {
    console.error('RawfileImageSaveUtil', `Failed to copy image to album target: ${JSON.stringify(error)}`)
    throw new Error(`Failed to copy image to album target: ${JSON.stringify(error)}`)
  } finally {
    closeFileQuietly(srcFile)
    closeFileQuietly(desFile)
  }
}

function closeFileQuietly(file: fileIo.File | null): void {
  if (file === null) {
    return
  }
  try {
    fileIo.closeSync(file)
  } catch (_) {
    // ignore close error
  }
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

function resolveImageExtension(path: string): string {
  const lower = path.toLowerCase()
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'jpg'
  }
  if (lower.endsWith('.webp')) {
    return 'webp'
  }
  return 'png'
}
