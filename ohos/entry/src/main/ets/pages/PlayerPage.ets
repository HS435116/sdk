import avPlayer from '@ohos.multimedia.avplayer';

@Entry
@Component
struct PlayerPage {
  private player?: avPlayer.AVPlayer;
  private controller: XComponentController = new XComponentController();
  @State private surfaceId: string = '';
  private args: Record<string, unknown> = (globalThis as Record<string, unknown>).__avPlayerArgs as Record<string, unknown> ?? {};

  aboutToAppear() {
    this.initPlayer();
  }

  aboutToDisappear() {
    this.releasePlayer();
  }

  private async initPlayer() {
    const url = this.args['url'] as string | undefined;
    if (!url) {
      return;
    }
    this.player = await avPlayer.createAVPlayer();
    const headers = this.args['headers'] as Record<string, string> | undefined;
    const playerAny = this.player as unknown as { setDataSource?: (src: Record<string, unknown>) => Promise<void> };
    if (playerAny.setDataSource) {
      await playerAny.setDataSource({ url, httpHeader: headers });
    } else {
      (this.player as unknown as { url?: string }).url = url;
    }
    if (this.surfaceId) {
      const surfaceSetter = this.player as unknown as { setSurfaceId?: (id: string) => void };
      if (surfaceSetter.setSurfaceId) {
        surfaceSetter.setSurfaceId(this.surfaceId);
      }
    }
    await this.player.prepare();
    await this.player.play();
  }

  private async releasePlayer() {
    if (!this.player) {
      return;
    }
    await this.player.stop();
    await this.player.release();
    this.player = undefined;
  }

  private bindSurface() {
    this.surfaceId = this.controller.getXComponentSurfaceId();
    if (this.player && this.surfaceId) {
      const surfaceSetter = this.player as unknown as { setSurfaceId?: (id: string) => void };
      if (surfaceSetter.setSurfaceId) {
        surfaceSetter.setSurfaceId(this.surfaceId);
      }
    }
  }

  build() {
    Stack() {
      XComponent({
        id: 'avplayer_surface',
        type: 'surface',
        controller: this.controller,
      }).onLoad(() => {
        this.bindSurface();
      }).width('100%').height('100%');
    }.width('100%').height('100%');
  }
}
