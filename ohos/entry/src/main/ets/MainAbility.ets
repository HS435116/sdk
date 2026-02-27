import { FlutterAbility, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';

export default class MainAbility extends FlutterAbility {
  private channel?: MethodChannel;

  onCreate(want: Record<string, unknown>, launchParam: Record<string, unknown>): void {
    super.onCreate(want, launchParam);
    this.initChannel();
  }

  private initChannel(): void {
    const engine = this.getFlutterEngine();
    if (!engine) {
      return;
    }
    this.channel = new MethodChannel(engine, 'harmony_avplayer');
    this.channel.setMethodCallHandler(this.onMethodCall.bind(this));
  }

  private async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'play') {
      await this.startAvPlayerAbility(call.args as Record<string, unknown>);
      result.success(true);
      return;
    }
    if (call.method === 'stop') {
      const ctx = (globalThis as Record<string, unknown>).__avPlayerAbilityContext as { terminateSelf?: () => void } | undefined;
      if (ctx && ctx.terminateSelf) {
        ctx.terminateSelf();
      }
      result.success(true);
      return;
    }
    result.notImplemented();
  }

  private async startAvPlayerAbility(args: Record<string, unknown>): Promise<void> {
    await this.context.startAbility({
      bundleName: this.context.bundleName,
      abilityName: 'AvPlayerAbility',
      parameters: args,
    });
  }
}
