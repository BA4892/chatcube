export class SendCancellationSignal {
  private cancelled: boolean = false

  cancel(): void {
    this.cancelled = true
  }

  isCancelled(): boolean {
    return this.cancelled
  }
}
