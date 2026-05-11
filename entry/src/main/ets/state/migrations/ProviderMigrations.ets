import { PreferenceKeys } from '../../services/PreferencesService'
import { MigrationContext } from './MigrationContext'
import { Migration } from './types'

const PROVIDER_MIGRATION_VERSION_KEY = PreferenceKeys.PROVIDER_MIGRATION_VERSION

class MiniMaxBaseUrlMigration implements Migration {
  version: number = 1
  description: string = 'fix MiniMax base URL (api.minimax.chat -> api.minimaxi.com)'

  async run(ctx: MigrationContext): Promise<void> {
    const configs = await ctx.db.getAllProviders()
    for (let i = 0; i < configs.length; i++) {
      const cfg = configs[i]
      if (cfg.id === 'minimax' && cfg.baseUrl === 'https://api.minimax.chat/v1') {
        await ctx.db.updateProviderBaseUrl('minimax', 'https://api.minimaxi.com/v1')
      }
    }
  }
}

const PROVIDER_MIGRATIONS: Migration[] = [
  new MiniMaxBaseUrlMigration()
]

export async function runProviderMigrations(ctx: MigrationContext): Promise<number> {
  let currentVersion = await ctx.preferences.getNumber(PROVIDER_MIGRATION_VERSION_KEY, 0)
  const migrations = PROVIDER_MIGRATIONS.slice().sort((a: Migration, b: Migration) => a.version - b.version)
  for (let i = 0; i < migrations.length; i++) {
    const migration = migrations[i]
    if (migration.version > currentVersion) {
      await migration.run(ctx)
      await ctx.preferences.setNumber(PROVIDER_MIGRATION_VERSION_KEY, migration.version)
      currentVersion = migration.version
    }
  }
  return currentVersion
}
