import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit'

export type ProviderShareScanError = 'cancelled' | 'no_qr' | 'unknown' | ''

export interface ProviderShareScanResult {
  ok: boolean
  payload: string
  error: ProviderShareScanError
}

class ProviderShareScanner {
  /**
   * 调起系统图库,让用户选一张图,然后用 ScanKit 解二维码。
   * 用户取消选图:ok=false, error='cancelled'。
   * 没识别到 QR:ok=false, error='no_qr'。
   */
  async pickImageAndDecodeQr(): Promise<ProviderShareScanResult> {
    let imageUri: string = ''
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const pickResult = await picker.select(options)
      if (pickResult.photoUris.length === 0) {
        return { ok: false, payload: '', error: 'cancelled' }
      }
      imageUri = pickResult.photoUris[0]
    } catch (err) {
      console.warn('ProviderShareScanner', `picker failed: ${JSON.stringify(err)}`)
      return { ok: false, payload: '', error: 'cancelled' }
    }

    try {
      const scanOpts: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      }
      const scanned: Array<scanBarcode.ScanResult> = await detectBarcode.decode({ uri: imageUri }, scanOpts)
      for (const item of scanned) {
        if (item.originalValue !== undefined && item.originalValue !== '') {
          return { ok: true, payload: item.originalValue, error: '' }
        }
      }
      return { ok: false, payload: '', error: 'no_qr' }
    } catch (err) {
      console.error('ProviderShareScanner', `decode failed: ${JSON.stringify(err)}`)
      return { ok: false, payload: '', error: 'unknown' }
    }
  }
}

let scannerInstance: ProviderShareScanner | null = null

export function getProviderShareScanner(): ProviderShareScanner {
  if (scannerInstance === null) {
    scannerInstance = new ProviderShareScanner()
  }
  return scannerInstance
}
