import { AgentConfig } from './AgentConfig';

@Entry
@Component
export struct Index {
  build() {
    Column() {
      AgentConfig()
    }
    .width('100%')
    .height('100%')
  }
}