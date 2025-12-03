import { AgentChat } from './AgentChat';

@Entry
@Component
export struct Index {
  build() {
    Column() {
      AgentChat()
    }
    .width('100%')
    .height('100%')
  }
}