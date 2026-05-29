import {
  ProviderDetailPanel,
  ProviderDetailPresentationMode
} from '../components/ProviderDetailSheet'
import { notifyModelManageRefresh } from './ModelManagePage'
import { getAppUiState } from '../state/AppUiState'

export interface ProviderDetailRouteParams {
  providerId?: string
  isCreateMode?: boolean
}

function resolveProviderDetailRouteParams(param: Object): ProviderDetailRouteParams {
  return param as ProviderDetailRouteParams
}

let providerDetailPagePathStack: NavPathStack | null = null

function popProviderDetailPage(): boolean {
  if (providerDetailPagePathStack === null || providerDetailPagePathStack.size() <= 0) {
    return false
  }
  providerDetailPagePathStack.pop()
  return true
}

@ComponentV2
struct ProviderDetailPageContent {
  @Param providerId: string = ''
  @Param isCreateMode: boolean = false
  @Event onClose: () => void = () => {}

  build() {
    Column() {
      ProviderDetailPanel({
        providerId: this.providerId,
        isCreateMode: this.isCreateMode,
        closeOnModelsSelected: false,
        presentationMode: ProviderDetailPresentationMode.PAGE,
        hostedInNavDestination: true,
        onClose: this.onClose,
        onDestinationReady: (context: NavDestinationContext) => {
          providerDetailPagePathStack = context.pathStack
        },
        onProviderChanged: (_providerId: string, _isCreateMode: boolean) => {
          notifyModelManageRefresh()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }
}

@Builder
export function ProviderDetailPageBuilder(name: string, param: Object) {
  ProviderDetailPageContent({
    providerId: resolveProviderDetailRouteParams(param).providerId ?? '',
    isCreateMode: resolveProviderDetailRouteParams(param).isCreateMode ?? false,
    onClose: () => {
      popProviderDetailPage()
    }
  })
}
