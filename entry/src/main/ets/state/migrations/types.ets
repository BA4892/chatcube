import { MigrationContext } from './MigrationContext'

export interface Migration {
  version: number
  description: string
  run(ctx: MigrationContext): Promise<void>
}
