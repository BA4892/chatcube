import {
  ImageGenerationAlertPayloadData,
  InAppTaskAlertPayloadData,
  OpenSessionPayloadData
} from '../models/TaskAlertModels'

export function parseOpenSessionPayload(payloadText: string): OpenSessionPayloadData | null {
  if (payloadText === '') {
    return null
  }
  try {
    const payload = JSON.parse(payloadText) as OpenSessionPayloadData
    if (payload.sessionId === '') {
      return null
    }
    return payload
  } catch (_error) {
    return null
  }
}

export function parseInAppTaskAlertPayload(payloadText: string): InAppTaskAlertPayloadData | null {
  if (payloadText === '') {
    return null
  }
  try {
    return JSON.parse(payloadText) as InAppTaskAlertPayloadData
  } catch (_error) {
    return null
  }
}

export function parseImageGenerationAlertPayload(payloadText: string): ImageGenerationAlertPayloadData | null {
  if (payloadText === '') {
    return null
  }
  try {
    return JSON.parse(payloadText) as ImageGenerationAlertPayloadData
  } catch (_error) {
    return null
  }
}
