import { PreferenceKeys } from '../../services/PreferencesService'
import { MigrationContext } from './MigrationContext'
import { Migration } from './types'

const ASSISTANT_MIGRATION_VERSION_KEY = PreferenceKeys.ASSISTANT_MIGRATION_VERSION

class AssistantTemplateColumnsMigration implements Migration {
  version: number = 1
  description: string = 'add assistant template fields'

  async run(ctx: MigrationContext): Promise<void> {
    await ctx.db.ensureAssistantTemplateColumns()
  }
}

const ASSISTANT_MIGRATIONS: Migration[] = [
  new AssistantTemplateColumnsMigration()
]

export async function runAssistantMigrations(ctx: MigrationContext): Promise<number> {
  let currentVersion = await ctx.preferences.getNumber(ASSISTANT_MIGRATION_VERSION_KEY, 0)
  const migrations = ASSISTANT_MIGRATIONS.slice().sort((a: Migration, b: Migration) => a.version - b.version)
  for (let i = 0; i < migrations.length; i++) {
    const migration = migrations[i]
    if (migration.version > currentVersion) {
      await migration.run(ctx)
      await ctx.preferences.setNumber(ASSISTANT_MIGRATION_VERSION_KEY, migration.version)
      currentVersion = migration.version
    }
  }
  return currentVersion
}
