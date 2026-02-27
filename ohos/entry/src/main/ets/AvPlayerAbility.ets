import UIAbility from '@ohos.app.ability.UIAbility';

export default class AvPlayerAbility extends UIAbility {
  onCreate(want: Record<string, unknown>, launchParam: Record<string, unknown>): void {
    super.onCreate(want, launchParam);
    (globalThis as Record<string, unknown>).__avPlayerArgs = want?.parameters ?? {};
    (globalThis as Record<string, unknown>).__avPlayerAbilityContext = this.context;
  }

  onWindowStageCreate(windowStage: { loadContent: (path: string, cb?: (err?: Error) => void) => void }): void {
    windowStage.loadContent('pages/PlayerPage');
  }
}
