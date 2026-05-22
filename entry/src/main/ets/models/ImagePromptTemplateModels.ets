@ObservedV2
export class ImagePromptTemplate {
  @Trace id: string = ''
  @Trace title: string = ''
  @Trace prompt: string = ''
  @Trace builtin: boolean = false
  @Trace order: number = 0
  @Trace createdAt: number = 0
  @Trace updatedAt: number = 0
}
