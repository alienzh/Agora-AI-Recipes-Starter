import { AgentHome } from './AgentHome';

@Entry
@Component
export struct Index {
  build() {
    Column() {
      AgentHome()
    }
    .width('100%')
    .height('100%')
  }
}