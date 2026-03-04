import router from '@ohos.router';
import { fetchHtml, parseListItems, kDefaultListUrl } from '../utils';

interface VideoItem {
  title: string;
  detailUrl: string;
  coverUrl: string;
  subTitle: string;
  badge: string;
}

const TABS: Array<{ title: string; url: string }> = [
  { title: '电影', url: 'https://www.jkan.app/show/1-----------.html' },
  { title: '电视剧', url: 'https://www.jkan.app/show/2-----------.html' },
  { title: '动漫', url: 'https://www.jkan.app/show/4-----------.html' },
  { title: '综艺', url: 'https://www.jkan.app/show/3-----------.html' }
];

@Entry
@Component
struct Index {
  @State items: VideoItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State keyword: string = '';
  @State currentUrl: string = kDefaultListUrl;

  aboutToAppear() {
    this.loadPage(this.currentUrl);
  }

  private async loadPage(url: string) {
    this.loading = true;
    this.error = '';
    this.currentUrl = url;
    try {
      const html = await fetchHtml(url);
      this.items = parseListItems(html) as VideoItem[];
      this.loading = false;
    } catch (e) {
      this.loading = false;
      this.error = '加载失败，请重试';
    }
  }

  private async onSearch() {
    const key = this.keyword.trim();
    if (!key) return;
    const url = `https://www.jkan.app/vodsearch/${encodeURIComponent(key)}----------1---.html`;
    await this.loadPage(url);
  }

  private openDetail(item: VideoItem) {
    router.pushUrl({
      url: 'pages/PlayerPage',
      params: { detailUrl: item.detailUrl, title: item.title }
    });
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('晨曦影视').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#FFFFFF');
          Blank();
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 6 });

        Row() {
          TextInput({ placeholder: '搜索影片…', text: this.keyword })
            .onChange((v: string) => this.keyword = v)
            .onSubmit(() => this.onSearch())
            .height(36)
            .layoutWeight(1)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#2A2A2A')
            .borderRadius(18)
            .fontColor('#FFFFFF');
          Button('搜索')
            .margin({ left: 8 })
            .height(36)
            .backgroundColor('#3A3A3A')
            .fontColor('#F06292')
            .onClick(() => this.onSearch());
        }
        .padding({ left: 16, right: 16, bottom: 8 });

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(TABS, (tab) => {
            Text(tab.title)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.currentUrl === tab.url ? '#3A3A3A' : '#2B2B2B')
              .fontColor(this.currentUrl === tab.url ? '#F06292' : '#FFFFFFB3')
              .borderRadius(18)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.loadPage(tab.url));
          }, (item) => item.title);
        }
        .padding({ left: 16, right: 16, bottom: 4 });

        if (this.loading) {
          Column() { Progress() }
            .height(240)
            .justifyContent(FlexAlign.Center);
        } else if (this.error) {
          Column() {
            Text(this.error).fontColor('#FF6B6B');
            Button('重试')
              .margin({ top: 8 })
              .backgroundColor('#3A3A3A')
              .fontColor('#FFFFFF')
              .onClick(() => this.loadPage(this.currentUrl));
          }
          .height(240)
          .justifyContent(FlexAlign.Center);
        } else if (this.items.length === 0) {
          Column() {
            Text('暂无内容').fontColor('#FFFFFF66');
          }
          .height(240)
          .justifyContent(FlexAlign.Center);
        } else {
          Grid() {
            ForEach(this.items, (item) => {
              GridItem() {
                Column() {
                  Stack() {
                    if (item.coverUrl) {
                      Image(item.coverUrl).objectFit(ImageFit.Cover);
                    } else {
                      Rect().fill('#333333');
                    }
                    if (item.badge) {
                      Text(item.badge)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor('#00000088')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .position({ x: 8, y: 8 });
                    }
                  }
                  .height(160)
                  .width('100%')
                  .borderRadius(12)
                  .clip(true);

                  Text(item.title)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 6 });
                  Text(item.subTitle)
                    .fontSize(10)
                    .fontColor('#FFFFFF80')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                }
                .padding(6)
                .backgroundColor('#262626')
                .borderRadius(12)
                .onClick(() => this.openDetail(item));
              }
            }, (item) => item.detailUrl);
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(12)
          .columnsGap(12)
          .padding({ left: 16, right: 16, bottom: 16 });
        }

        Text('2026 © 晨曦微光')
          .fontColor('#FFFFFF60')
          .fontSize(11)
          .margin({ top: 8, bottom: 24 })
          .alignSelf(ItemAlign.Center);
      }
      .width('100%');
    }
    .backgroundColor('#1E1E1E')
    .width('100%')
    .height('100%');
  }
}
