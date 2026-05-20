import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

export async function saveRawfileImageToAlbum(
  context: common.UIAbilityContext,
  rawFileName: string,
  titlePrefix: string
): Promise<void> {
  const rawFileData = context.resourceManager.getRawFileContentSync(rawFileName)
  const extension = rawFileName.toLowerCase().endsWith('.png') ? 'png' : 'jpg'
  const tempPath = `${context.cacheDir}/${titlePrefix}_${Date.now()}.${extension}`
  const tempFile = fileIo.openSync(tempPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
  fileIo.writeSync(tempFile.fd, rawFileData.buffer)
  fileIo.closeSync(tempFile)

  try {
    const tempUriStr = fileUri.getUriFromPath(tempPath)
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

    let srcFile: fileIo.File | null = null
    let desFile: fileIo.File | null = null
    try {
      srcFile = fileIo.openSync(tempPath, fileIo.OpenMode.READ_ONLY)
      desFile = fileIo.openSync(desFileUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      await fileIo.copyFile(srcFile.fd, desFile.fd)
    } finally {
      closeFileQuietly(srcFile)
      closeFileQuietly(desFile)
    }
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
  const srcUri = fileUri.getUriFromPath(localPath)
  const extension = resolveImageExtension(localPath)
  const config: photoAccessHelper.PhotoCreationConfig = {
    title: `${titlePrefix}_${Date.now()}`,
    fileNameExtension: extension,
    photoType: photoAccessHelper.PhotoType.IMAGE,
    subtype: photoAccessHelper.PhotoSubtype.DEFAULT
  }
  const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
  const desFileUris = await phAccessHelper.showAssetsCreationDialog([srcUri], [config])
  if (desFileUris.length === 0) {
    throw new Error('User cancelled save')
  }

  let srcFile: fileIo.File | null = null
  let desFile: fileIo.File | null = null
  try {
    srcFile = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY)
    desFile = fileIo.openSync(desFileUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    await fileIo.copyFile(srcFile.fd, desFile.fd)
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
