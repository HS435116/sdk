import router from '@ohos.router';
import avPlayer from '@ohos.multimedia.avplayer';
import { fetchHtml, parsePlayUrlFromHtml, findPlayPageUrl, defaultHeaders, kBaseHost } from '../utils';

@Entry
@Component
struct PlayerPage {
  private player?: avPlayer.AVPlayer;
  private controller: XComponentController = new XComponentController();
  @State private surfaceId: string = '';
  @State private loading: boolean = true;
  @State private error: string = '';
  private detailUrl: string = '';
  private title: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.detailUrl = params?.detailUrl ?? '';
    this.title = params?.title ?? '';
    this.startPlay();
  }

  aboutToDisappear() {
    this.releasePlayer();
  }

  private async startPlay() {
    this.loading = true;
    this.error = '';
    try {
      const detailHtml = await fetchHtml(this.detailUrl);
      let playUrl = parsePlayUrlFromHtml(detailHtml);
      if (!playUrl) {
        const playPage = findPlayPageUrl(detailHtml);
        if (playPage) {
          const playHtml = await fetchHtml(playPage);
          playUrl = parsePlayUrlFromHtml(playHtml);
        }
      }
      if (!playUrl) throw new Error('no play url');
      await this.initPlayer(playUrl);
      this.loading = false;
    } catch (e) {
      this.loading = false;
      this.error = '播放失败，请重试或切换视频源';
    }
  }

  private async initPlayer(url: string) {
    this.player = await avPlayer.createAVPlayer();
    const headers = defaultHeaders(this.detailUrl || kBaseHost);
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
    if (!this.player) return;
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
      XComponent({ id: 'avplayer_surface', type: 'surface', controller: this.controller })
        .onLoad(() => this.bindSurface())
        .width('100%')
        .height('100%');

      Row() {
        Button('返回')
          .backgroundColor('#00000066')
          .fontColor('#FFFFFF')
          .height(32)
          .onClick(() => router.back());
        Text(this.title)
          .fontColor('#FFFFFF')
          .fontSize(14)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 8 })
          .layoutWeight(1);
      }
      .padding({ left: 12, right: 12, top: 12 })
      .position({ x: 0, y: 0 });

      if (this.loading) {
        Column() { Progress() }.height('100%').justifyContent(FlexAlign.Center);
      }
      if (this.error) {
        Column() {
          Text(this.error).fontColor('#FF6B6B');
          Button('重试')
            .margin({ top: 8 })
            .backgroundColor('#3A3A3A')
            .fontColor('#FFFFFF')
            .onClick(() => this.startPlay());
        }.height('100%').justifyContent(FlexAlign.Center);
      }
    }
    .backgroundColor('#000000')
    .width('100%')
    .height('100%');
  }
}
