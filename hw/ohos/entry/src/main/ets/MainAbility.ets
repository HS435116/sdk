import UIAbility from '@ohos.app.ability.UIAbility';

export default class MainAbility extends UIAbility {
  onWindowStageCreate(windowStage: { loadContent: (path: string, cb?: (err?: Error) => void) => void }): void {
    windowStage.loadContent('pages/Index');
  }
}
