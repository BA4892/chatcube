import { DatabaseService } from '../../services/DatabaseService'
import { PreferencesService } from '../../services/PreferencesService'
import { AppSettingsState } from '../AppSettingsState'

export class MigrationContext {
  db: DatabaseService
  preferences: PreferencesService
  state: AppSettingsState

  constructor(db: DatabaseService, preferences: PreferencesService, state: AppSettingsState) {
    this.db = db
    this.preferences = preferences
    this.state = state
  }
}
